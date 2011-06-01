package Courriel::Part::Single;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Helpers qw( parse_header_with_attributes );
use Courriel::Types qw( StringRef );
use Email::MIME::Encodings;
use MIME::Base64 ();
use MIME::QuotedPrint ();

use Moose;

with 'Courriel::Role::Part';

has content => (
    is       => 'ro',
    isa      => StringRef,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_content',
);

has raw_content => (
    is       => 'ro',
    isa      => StringRef,
    coerce   => 1,
    required => 1,
    init_arg => 'raw_content',
);

has disposition => (
    is       => 'ro',
    isa      => 'Courriel::Disposition',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_disposition',
    handles  => [qw( is_attachment is_inline filename )],
);

sub BUILD {
    my $self = shift;

    ${ $self->raw_content() }
        =~ s/$Courriel::Helpers::LINE_SEP_RE/$Courriel::Helpers::CRLF/g;

    return;
}

sub _build_disposition {
    my $self = shift;

    my @disp = $self->headers()->get('Content-Disposition');
    if ( @disp > 1 ) {
        die 'This email defines more than one Content-Disposition header.';
    }

    my ( $disposition, $attributes )
        = defined $disp[0]
        ? parse_header_with_attributes( $disp[0] )
        : ( 'inline', {} );

    return Courriel::Disposition->new(
        disposition => $disposition,
        attributes  => $attributes,
    );
}

sub is_multipart {0}

sub _build_content_type {
    return Courriel::ContentType->new( mime_type => 'text/plain' );
}

{
    my %unencoded = map { $_ => 1 } qw( 7bit 8bit binary );

    sub _build_content {
        my $self = shift;

        my $encoding = $self->encoding();

        return $self->raw_content() if $unencoded{ lc $encoding };

        return \(
            Email::MIME::Encodings::decode(
                $encoding,
                ${ $self->raw_content() }
            )
        );
    }
}

sub _content_as_string {
    my $self = shift;

    return ${ $self->raw_content() };
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: A part which does not contain other parts, only content

__END__

=head1 SYNOPSIS

  my $headers = $part->headers();
  my $ct = $part->content_type();

  my $content = $part->content();
  print ${$content};

=head1 DESCRIPTION

This class represents a single part that does not contain other parts, just
content.

=head1 API

This class provides the following methods:

=head1 Courriel::Part::Single->new( ... )

This method creates a new part object. It accepts the following parameters:

=over 4

=item * raw_content

This can either be a string or a reference to a scalar. Any reference passed
may be modified.

=item * content_type

A L<Courriel::ContentType> object. This will default to one with the mime type
"text/plain".

=item * disposition

A L<Courriel::Disposition> object representing this part's content
disposition. This will default to "inline" with no other attributes.

=item * encoding

The Content-Transfer-Encoding for this part. This defaults to "8bit".

=item * headers

A L<Courriel::Headers> object contaning headers for this part.

=back

=head2 $part->content()

This returns returns a reference to a scalar containing the decoded content
for the part. If no decoding was necessary, this will contain the same
reference as C<raw_content()>.

=head2 $part->raw_content()

This returns returns a reference to a scalar containing the raw content for
the part, without any decoding.

=head2 $part->mime_type()

Returns the mime type for this part.

=head2 $part->charset()

Returns the charset for this part.

=head2 $part->is_inline(), $part->is_attachment()

These methods return boolean values based on the part's content disposition.

=head2 $part->filename()

Returns the filename from the part's content disposition, if any.

=head2 $part->content_type()

Returns the L<Courriel::ContentType> object for this part.

=head2 $part->disposition()

Returns the L<Courriel::Disposition> object for this part.

=head2 $part->encoding()

Returns the encoding for the part.

=head2 $part->headers()

Returns the L<Courriel::Headers> object for this part.

=head2 $part->is_multipart()

Returns false.

=head2 $part->container()

Returns the L<Courriel> or L<Courriel::Part::Multipart> object to which this
part belongs, if any. This is set when the part is added to another object.

=head2 $part->as_string()

Returns the part as a string, along with its headers. Lines will be terminated
with "\r\n".

=head1 ROLES

This class does the C<Courriel::Role::Part> role.

