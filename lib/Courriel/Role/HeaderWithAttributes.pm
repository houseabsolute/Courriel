package Courriel::Role::HeaderWithAttributes;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::HeaderAttribute;
use Courriel::Types qw( HashRef );
use Scalar::Util qw( blessed reftype );

use Moose::Role;

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

sub _attributes_as_string {
    my $self = shift;

    my $attr = $self->_attributes();

    return join '; ', map { $attr->{$_}->as_string() } sort keys %{$attr};
}

1;
