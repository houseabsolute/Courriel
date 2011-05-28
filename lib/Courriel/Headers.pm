package Courriel::Headers;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Types qw( ArrayRef Defined EvenArrayRef HashRef NonEmptyStr Str StringRef );
use Encode qw( decode );
use Hash::MultiValue;
use MooseX::Params::Validate qw( pos_validated_list validated_list );

use Moose;

with 'Courriel::Role::Headers';

has _headers => (
    traits   => ['Array'],
    is       => 'ro',
    isa      => EvenArrayRef [Str],
    default  => sub { [] },
    init_arg => 'headers',
    handles  => {
        headers => 'elements',
    },
);

# The _key_indices field, along with all the complicated code to
# get/add/remove headers below, is necessary because RFC 5322 says:
#
#   However, for the purposes of this specification, header fields SHOULD NOT
#   be reordered when a message is transported or transformed.  More
#   importantly, the trace header fields and resent header fields MUST NOT be
#   reordered, and SHOULD be kept in blocks prepended to the message.
#
# So we store headers as an array ref. When we add additional values for a
# header, we will put them after the last header of the same name in the array
# ref. If no such header exists yet, then we just put them at the end of the
# arrayref.

has _key_indices => (
    traits   => ['Hash'],
    isa      => HashRef [ ArrayRef [NonEmptyStr] ],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_key_indices',
    clearer  => '_clear_key_indices',
    handles  => {
        __key_indices_for => 'get',
    },
);

sub _build_key_indices {
    my $self = shift;

    my $headers = $self->_headers();

    my %indices;
    for ( my $i = 0; $i < @{$headers}; $i += 2 ) {
        push @{ $indices{ lc $headers->[$i] } }, $i + 1;
    }

    return \%indices;
}

sub get {
    my $self = shift;
    my ($key) = pos_validated_list(
        \@_,
        { isa => NonEmptyStr },
    );

    return @{ $self->_headers() }[ $self->_key_indices_for($key) ];
}

sub _key_indices_for {
    my $self = shift;
    my $key  = shift;

    return @{ $self->__key_indices_for( lc $key ) || [] };
}

sub add {
    my $self = shift;
    my ( $key, @vals ) = pos_validated_list(
        \@_,
        { isa => NonEmptyStr },
        ( { isa => Defined } ) x ( @_ - 1 ),
        MX_PARAMS_VALIDATE_NO_CACHE => 1,
    );

    my $headers = $self->_headers();

    my $last_index = ( $self->_key_indices_for($key) )[-1];

    my @keyed_vals = map { $key => $_ } @vals;

    if ( $last_index ) {
        splice @{$headers}, $last_index + 1, 0, @keyed_vals;
    }
    else {
        push @{$headers}, @keyed_vals;
    }

    $self->_clear_key_indices();

    return;
}

# Used to add things like Resent or Received headers
sub unshift {
    my $self = shift;

    my ( $key, @vals ) = pos_validated_list(
        \@_,
        { isa => NonEmptyStr },
        ( { isa => Defined } ) x ( @_ - 1 ),
        MX_PARAMS_VALIDATE_NO_CACHE => 1,
    );

    my $headers = $self->_headers();

    unshift @{$headers}, map { $key => $_ } @vals;

    return;
}

sub remove {
    my $self = shift;
    my ($key) = pos_validated_list(
        \@_,
        { isa => NonEmptyStr },
    );

    my $headers = $self->_headers();

    for my $idx ( reverse $self->_key_indices_for($key) ) {
        splice @{$headers}, $idx - 1, 2;
    }

    $self->_clear_key_indices();

    return;
}

{
    my $horiz_ws = qr/[ \t]/;
    my $line_re = qr/
                     (?:
                         ([^\s:][^:]*)  # a header name
                         :              # followed by a colon
                         $horiz_ws*
                         (.*)           # header value - can be empty
                     )
                     |
                     $horiz_ws+(.+)            # continuation line
                    /x;

    sub parse {
        my $class = shift;
        my ( $text, $sep ) = validated_list(
            \@_,
            text     => { isa => StringRef, coerce => 1 },
            line_sep => { isa => NonEmptyStr, default => "\x0d\x0a" },
        );

        my $sep_re = qr/$sep/;

        my @headers;

        while ( ${$text} =~ /\G${line_re}${sep_re}/gc ) {
            if ( defined $1 ) {
                push @headers, $1, $2;
            }
            else {
                die
                    'Header text contains a continuation line before a header name has been seen.'
                    unless @headers;

                $headers[-1] //= q{};
                $headers[-1] .= q{ } . $3;
            }
        }

        my $pos = pos ${$text} // 0;
        if ( $pos != length ${$text} ) {
            my @lines = split $sep_re, substr( ${$text}, 0, $pos );
            my $count = ( scalar @lines ) + 1;

            die "Found an unparseable chunk in the header text starting at line $count.";
        }

        for ( my $i = 1; $i < @headers; $i += 2 ) {
            next unless $headers[$i] =~ /^=\?/;

            $headers[$i] = decode( 'MIME-Header', $headers[$i] );
        }

        return $class->new( headers => \@headers );
    }
}

1;
