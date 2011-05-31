package Courriel::Part::Multipart;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Types qw( NonEmptyStr );
use Email::MessageID;

use Moose;

with 'Courriel::Role::Part', 'Courriel::Role::HasParts';

has boundary => (
    is      => 'ro',
    isa     => NonEmptyStr,
    lazy    => 1,
    builder => '_build_boundary',
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

sub _content_as_string {
    my $self = shift;

    my $content;
    $content .=  $self->preamble() . $Courriel::Helpers::CRLF
        if $self->has_preamble();

    $content
        .= '--'
        . $self->boundary()
        . $Courriel::Helpers::CRLF
        . $_->as_string()
        for $self->parts();

    $content .= '--' . $self->boundary() . '--' . $Courriel::Helpers::CRLF;

    $content .= $self->epilogue() . $Courriel::Helpers::CRLF
        if $self->has_epilogue();

    return $content;
}

sub _build_boundary {
    return Email::MessageID->new()->user();
}

__PACKAGE__->meta()->make_immutable();

1;
