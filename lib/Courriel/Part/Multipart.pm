package Courriel::Part::Multipart;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Helpers qw( unique_boundary );
use Courriel::Types qw( NonEmptyStr );
use Email::MessageID;

use Moose;
use MooseX::StrictConstructor;

with 'Courriel::Role::Part', 'Courriel::Role::HasParts';

has boundary => (
    is        => 'ro',
    isa       => NonEmptyStr,
    lazy      => 1,
    builder   => '_build_boundary',
    predicate => '_has_boundary',
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

sub BUILD {
    my $self = shift;

    # XXX - this is a nasty hack but I'm not sure if it can better. We want
    # the boundary in the ContentType object to match the one in this part.
    if ( $self->_has_boundary() ) {
        $self->content_type()->_attributes()->{boundary} = $self->boundary();
    }
    else {
        # This is being called to force the builder to run.
        $self->boundary();
    }

    return;
}

sub is_attachment {0}
sub is_inline     {0}
sub is_multipart  {1}

sub _default_mime_type {
    return 'multipart/mixed';
}

sub _content_as_string {
    my $self = shift;

    my $content;
    $content .=  $self->preamble() . $Courriel::Helpers::CRLF
        if $self->has_preamble();

    $content
        .= $Courriel::Helpers::CRLF . '--'
        . $self->boundary()
        . $Courriel::Helpers::CRLF
        . $_->as_string()
        for $self->parts();

    $content
        .= $Courriel::Helpers::CRLF . '--'
        . $self->boundary() . '--'
        . $Courriel::Helpers::CRLF;

    $content .= $self->epilogue() . $Courriel::Helpers::CRLF
        if $self->has_epilogue();

    return $content;
}

sub _build_boundary {
    my $self = shift;

    my $attr = $self->content_type()->_attributes();

    return $attr->{boundary} //= unique_boundary();
}

around _build_content_type => sub {
    my $orig = shift;
    my $self = shift;

    my $ct = $self->$orig(@_);

    return $ct unless $self->_has_boundary();

    $ct->_attributes()->{boundary} = $self->boundary();

    return $ct;
};

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: A part which contains other parts

__END__

=head1 SYNOPSIS

  my $headers = $part->headers();
  my $ct = $part->content_type();

  for my $subpart ( $part->parts ) { ... }

=head1 DESCRIPTION

This class represents a multipart email part which contains other parts.

=head1 API

This class provides the following methods:

=head2 Courriel::Part::Multipart->new( ... )

This method creates a new part object. It accepts the following parameters:

=over 4

=item * parts

An array reference of part objects (either Single or Multipart). This is
required, but could be empty.

=item * content_type

A L<Courriel::ContentType> object. This defaults to one with a mime type of
"multipart/mixed".

=item * boundary

The part boundary. If none is provided, a unique value will be generated.

=item * preamble

Content that appears before the first part boundary. This will be seen by
email clients that don't understand multipart messages.

=item * epilogue

Content that appears after the final part boundary. The spec allows for this,
but it's probably not very useful.

=item * headers

A L<Courriel::Headers> object containing headers for this part.

=back

=head2 $part->parts()

Returns an array (not a reference) of the parts this part contains.

=head2 $part->part_count()

Returns the number of parts this part contains.

=head2 $part->boundary()

Returns the part boundary.

=head2 $part->mime_type()

Returns the mime type for this part.

=head2 $part->content_type()

Returns the L<Courriel::ContentType> object for this part.

=head2 $part->headers()

Returns the L<Courriel::Headers> object for this part.

=head2 $part->is_inline(), $part->is_attachment()

These methods always return false, but exist for the sake of providing a
consistent API between Single and Multipart part objects.

=head2 $part->is_multipart()

Returns true.

=head2 $part->preamble()

The preamble as passed to the constructor.

=head2 $part->epilogue()

The epilogue as passed to the constructor.

=head2 $part->container()

Returns the L<Courriel> or L<Courriel::Part::Multipart> object to which this
part belongs, if any. This is set when the part is added to another object.

=head2 $part->as_string()

Returns the part as a string, along with its headers. Lines will be terminated
with "\r\n".

=head1 ROLES

This class does the C<Courriel::Role::Part> and C<Courriel::Role::HasParts>
roles.
