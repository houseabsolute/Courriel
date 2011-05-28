package Courriel::ContentType;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Types qw( Charset HashRef NonEmptyStr );

use Moose;

has mime_type => (
    is       => 'ro',
    isa      => NonEmptyStr,
    required => 1,
);

has charset => (
    is      => 'ro',
    isa     => Charset,
    default => 'us-ascii',
);

has attributes => (
    is      => 'ro',
    isa     => HashRef [NonEmptyStr],
    default => sub { {} },
);

1;
