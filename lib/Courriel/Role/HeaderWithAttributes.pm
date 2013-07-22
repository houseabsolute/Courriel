package Courriel::Role::HeaderWithAttributes;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::HeaderAttribute;
use Courriel::Helpers qw( parse_header_with_attributes );
use Courriel::Types qw( HashRef NonEmptyStr );
use MooseX::Params::Validate qw( pos_validated_list validated_list );
use Scalar::Util qw( blessed reftype );

use MooseX::Role::Parameterized;

parameter default_header_name => (
    isa      => NonEmptyStr,
    required => 1,
);

parameter main_value_key => (
    isa      => NonEmptyStr,
    required => 1,
);

parameter main_value_method => (
    isa => NonEmptyStr,
);

has _attributes => (
    traits   => ['Hash'],
    is       => 'ro',
    isa      => HashRef ['Courriel::HeaderAttribute'],
    init_arg => 'attributes',
    default  => sub { {} },
    handles  => {
        attributes      => 'elements',
        _attribute      => 'get',
        _set_attribute  => 'set',
        _has_attributes => 'count',
    },
);

sub attribute {
    my $self = shift;
    my $key  = shift;

    return unless defined $key;

    return $self->_attribute( lc $key );
}

{
    my @spec = ( { isa => NonEmptyStr } );

    sub attribute_value {
        my $self = shift;
        my ($name) = pos_validated_list( \@_, @spec );

        my $attr = $self->attribute($name);

        return $attr ? $attr->value() : undef;
    }
}

sub _attributes_as_string {
    my $self = shift;

    my $attr = $self->_attributes();

    return join '; ', map { $attr->{$_}->as_string() } sort keys %{$attr};
}

role {
    my $p = shift;

    my $main_value_key = $p->main_value_key();

    method _parse_header => sub {
        my $self  = shift;
        my $value = shift;

        my ( $main_value, $attributes )
            = parse_header_with_attributes($value);

        return (
            value           => $value,
            $main_value_key => $main_value,
            attributes      => $attributes,
        );
    };

    my $main_value_meth = $p->main_value_method() || $p->main_value_key();

    method as_header_value => sub {
        my $self = shift;

        my $string = $self->$main_value_meth();

        if ( $self->_has_attributes() ) {
            $string .= '; ';
            $string .= $self->_attributes_as_string();
        }

        return $string;
    };

    my $name = $p->default_header_name();

    around BUILDARGS => sub {
        my $orig  = shift;
        my $class = shift;

        my $p = $class->$orig(@_);

        $p->{name} = $name unless exists $p->{name};

        return $p
            unless $p->{attributes} && reftype( $p->{attributes} ) eq 'HASH';

        for my $name ( keys %{ $p->{attributes} } ) {
            my $lc_name = lc $name;
            $p->{attributes}{$lc_name} = delete $p->{attributes}{$name};

            next if blessed( $p->{attributes}{$lc_name} );

            $p->{attributes}{$lc_name} = Courriel::HeaderAttribute->new(
                name  => $name,
                value => $p->{attributes}{$name},
            );
        }

        return $p;
    };

    # Deprecated
    method new_from_value => sub {
        my $class = shift;
        my %p     = @_;

        $p{name} //= $name;
        $p{raw_value} = delete $p{value};

        return $class->new(%p);
    };
};

1;
