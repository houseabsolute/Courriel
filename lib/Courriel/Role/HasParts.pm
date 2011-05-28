package Courriel::Role::HasParts;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Types qw( ArrayRef Part );

use Moose::Role;

has _parts => (
    isa => ArrayRef [Part],
    init_arg => 'parts',
    required => 1,
    handles  => {
        parts => 'elements',
    },
);

sub BUILD { }

after BUILD => sub {
    my $self = shift;

    $_->_set_container($self) for $self->parts();

    return;
};

1;
