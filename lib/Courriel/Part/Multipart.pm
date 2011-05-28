package Courriel::Part::Multipart;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Types qw( NonEmptyStr );

use Moose;

with 'Courriel::Role::Part', 'Courriel::Role::HasParts';

has boundary => (
    is       => 'ro',
    isa      => NonEmptyStr,
    required => 1,
);

has preamble => (
    is        => 'ro',
    isa       => NonEmptyStr,
    predicate => 'has_preamble',
);

has epilogue => (
    is        => 'ro',
    isa       => NonEmptyStr,
    predicate => 'has_epilogue',
);

sub is_multipart {1}

sub _build_content_type {
    return Courriel::ContentType->new( mime_type => 'multipart/mixed' );
}

1;
