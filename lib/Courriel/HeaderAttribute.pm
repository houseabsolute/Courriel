package Courriel::HeaderAttribute;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::HeaderAttribute;
use Courriel::Helpers qw( quote_and_escape_attribute_value );
use Courriel::Types qw( Maybe NonEmptyStr Str );
use Encode qw( encode );

use Moose;
use MooseX::StrictConstructor;

has name => (
    is       => 'ro',
    isa      => NonEmptyStr,
    required => 1,
);

has value => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has charset => (
    is      => 'ro',
    isa     => NonEmptyStr,
    default => 'us-ascii',
);

has language => (
    is      => 'ro',
    isa     => Maybe [NonEmptyStr],
    default => undef,
);

override BUILDARGS => sub {
    my $class = shift;

    my $p = super();

    return $p unless defined $p->{value};

    $p->{charset} = 'UTF-8' if $p->{value} =~ /[^\p{ASCII}]/;

    return $p;
};

{
    my $non_attribute_char = qr{
                                   $Courriel::Helpers::TSPECIALS
                               |
                                   [ \*\%]           # space, *, %
                               |
                                   [^\p{ASCII}]      # anything that's not ascii
                               |
                                   [\x00-\x1f\x7f]   # ctrl chars
                           }x;

    sub as_string {
        my $self = shift;

        my $value = $self->value();

        my $transport_method = '_simple_parameter';

        if (   $value =~ /[\x00-\x1f]|\x7f|[^\p{ASCII}]/
            || defined $self->language()
            || $self->charset() ne 'us-ascii' ) {

            $value = encode( 'utf-8', $value );
            $value
                =~ s/($non_attribute_char)/'%' . uc sprintf( '%02x', ord($1) )/eg;

            $transport_method = '_encoded_parameter';
        }
        elsif ( $value =~ /$non_attribute_char/ ) {
            $transport_method = '_quoted_parameter';
        }

        # XXX - hard code 78 as the max line length may not be right. Should
        # this account for the length that the parameter name takes up (as
        # well as encoding information, etc.)?

        my @pieces;
        while ( length $value ) {
            my $last_percent = rindex( $value, '%', 78 );
            my $size
                = $last_percent >= 76 ? $last_percent - 1
                : length $value > 78  ? 78
                :                       length $value;

            push @pieces, substr( $value, 0, $size, q{} );
        }

        if ( @pieces == 1 ) {
            return $self->$transport_method( undef, $pieces[0] );
        }
        else {
            return join q{ },
                map { $self->$transport_method( $_, $pieces[$_] ) }
                0 .. $#pieces;
        }
    }
}

sub _simple_parameter {
    my $self  = shift;
    my $order = shift;
    my $value = shift;

    my $param = $self->name();
    $param .= q{*} . $order if defined $order;
    $param .= q{=};
    $param .= $value;

    return $param;
}

sub _quoted_parameter {
    my $self  = shift;
    my $order = shift;
    my $value = shift;

    my $param = $self->name();
    $param .= q{*} . $order if defined $order;
    $param .= q{=};

    $value =~ s/\"/\\\"/g;

    $param .= q{"} . $value . q{"};

    return $param;
}

sub _encoded_parameter {
    my $self  = shift;
    my $order = shift;
    my $value = shift;

    my $param = $self->name();
    $param .= q{*} . $order if defined $order;
    $param .= q{*=};

    # XXX (1) - does it makes sense to just say everything is utf-8? in theory
    # someone could pass through binary data in another encoding.
    unless ($order) {
        $param .= 'UTF-8' . q{'}
            . ( $self->language() // q{} ) . q{'};
    }

    $param .= $value;

    return $param;
}

1;
