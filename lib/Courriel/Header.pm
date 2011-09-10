package Courriel::Header;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::HeaderAttribute;
use Courriel::Types qw( NonEmptyStr Str );

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

__PACKAGE__->meta()->make_immutable();

1;
