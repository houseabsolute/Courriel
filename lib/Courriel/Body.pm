package Courriel::Part;

use strict;
use warnings;
use namespace::autoclean;

use Hash::MultiValue;

use Moose;

with 'Courriel::Role::Part';

has _content => (
    isa      => ScalarRef,
    coerce   => 1,
    required => 1,
    init_arg => 'content',
    handles  => {

    },
);

1;
