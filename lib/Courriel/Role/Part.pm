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

around _build_content_type => sub {
    my $orig = shift;
    my $self = shift;

    my $ct = $self->$orig(@_);

    $self->headers()->remove('Content-Type');
    $self->headers()->add( 'Content-Type' => $ct->as_header_value() );

    return $ct;
};

1;
