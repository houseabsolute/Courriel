package Courriel::Role::Part;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::ContentType;
use Courriel::Disposition;

use Courriel::Types qw( NonEmptyStr );

use Moose::Role;

requires qw( _build_content_type _content_as_string );

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

has content_type => (
    is      => 'ro',
    isa     => 'Courriel::ContentType',
    lazy    => 1,
    builder => '_build_content_type',
    handles => [qw( mime_type charset )],
);

has encoding => (
    is      => 'ro',
    isa     => NonEmptyStr,
    default => '8bit',
);

sub as_string {
    my $self = shift;

    return
          $self->headers()->as_string()
        . $Courriel::Helpers::CRLF
        . $self->_content_as_string();
}

1;
