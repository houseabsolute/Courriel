package Courriel::ContentType;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Types qw( HashRef NonEmptyStr );

use Moose;

has mime_type => (
    is       => 'ro',
    isa      => NonEmptyStr,
    required => 1,
);

has charset => (
    is      => 'ro',
    isa     => NonEmptyStr,
    lazy    => 1,
    builder => '_build_charset',
);

has attributes => (
    is      => 'ro',
    isa     => HashRef [NonEmptyStr],
    default => sub { {} },
);

sub _build_charset {
    my $self = shift;

    return $self->attributes()->{charset} // 'us-ascii';
}

__PACKAGE__->meta()->make_immutable();

1;
