package Courriel::Role::HasContentType;

use strict;
use warnings;
use namespace::autoclean;

use Moose::Role;

use Courriel::Types qw( ContentType Encoding );

requires '_build_content_type';

has content_type => (
    is      => 'ro',
    isa     => ContentType,
    lazy    => 1,
    builder => '_build_content_type',
);

has encoding => (
    is      => 'ro',
    isa     => Encoding,
    default => '8bit',
);

1;
