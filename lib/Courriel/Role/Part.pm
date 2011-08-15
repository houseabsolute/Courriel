package Courriel::Role::Part;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::ContentType;
use Courriel::Disposition;
use Courriel::Helpers qw( parse_header_with_attributes );

use Courriel::Types qw( NonEmptyStr );

use Moose::Role;

requires qw( _default_mime_type _content_as_string );

has headers => (
    is       => 'rw',
    writer   => '_set_headers',
    does     => 'Courriel::Headers',
    required => 1,
);

has container => (
    is       => 'rw',
    writer   => '_set_container',
    isa      => 'Courriel::Part::Multipart',
    weak_ref => 1,
);

has content_type => (
    is        => 'ro',
    isa       => 'Courriel::ContentType',
    lazy      => 1,
    builder   => '_build_content_type',
    predicate => '_has_content_type',
    handles   => [qw( mime_type charset has_charset )],
);

sub as_string {
    my $self = shift;

    return
          $self->headers()->as_string()
        . $Courriel::Helpers::CRLF
        . $self->_content_as_string();
}

sub _build_content_type {
    my $self = shift;

    my @ct = $self->headers()->get('Content-Type');
    if ( @ct > 1 ) {
        die 'This part defines more than one Content-Type header.';
    }

    my ( $mime, $attr )
        = defined $ct[0]
        ? parse_header_with_attributes( $ct[0] )
        : ( 'text/plain', {} );

    return Courriel::ContentType->new(
        mime_type  => $mime,
        attributes => $attr,
    );
}

after BUILD => sub {
    my $self = shift;

    $self->_maybe_set_content_type_in_headers();

    return;
};

after _set_headers => sub {
    my $self = shift;

    $self->_maybe_set_content_type_in_headers();

    return;
};

sub _maybe_set_content_type_in_headers {
    my $self = shift;

    return unless $self->_has_content_type();

    $self->headers()
        ->replace(
        'Content-Type' => $self->content_type()->as_header_value() );
}

1;
