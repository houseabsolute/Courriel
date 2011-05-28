package Courriel::Role::Part;

use strict;
use warnings;
use namespace::autoclean;

use Moose::Role;

with 'Courriel::Role::HasContentType';

has headers => (
    is       => 'ro',
    does     => 'Courriel::Headers',
    required => 1,
);

has container => (
    is       => 'rw',
    writer   => '_set_container',
    does     => 'Courriel::Role::HasParts',
    weak_ref => 1,
);

1;
