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
        attribute       => 'get',
        _has_attributes => 'count',
    },
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my $p = $class->$orig(@_);

    return $p
        unless $p->{attributes} && reftype( $p->{attributes} ) eq 'HASH';

    for my $name ( keys %{ $p->{attributes} } ) {
        next if blessed( $p->{attributes}{$name} );

        $p->{attributes}{$name} = Courriel::HeaderAttribute->new(
            name  => $name,
            value => $p->{attributes}{$name},
        );
    }

    return $p;
};

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

{
    my @spec = (
        name  => { isa => NonEmptyStr, optional => 1 },
        value => { isa => NonEmptyStr },
    );

    role {
        my $p = shift;

        my $main_value_key = $p->main_value_key();

        method new_from_value => sub {
            my $class = shift;
            my ( $name, $value ) = validated_list( \@_, @spec );

            my ( $main_value, $attributes )
                = parse_header_with_attributes($value);

            my %p = (
                value           => $value,
                $main_value_key => $main_value,
                attributes      => $attributes,
            );

            $p{name} = $name if defined $name;

            return $class->new(%p);
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
    }
}

1;
