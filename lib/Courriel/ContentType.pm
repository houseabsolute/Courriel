package Courriel::ContentType;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Helpers qw( quote_and_escape_attribute_value );
use Courriel::Types qw( HashRef NonEmptyStr );

use Moose;
use MooseX::StrictConstructor;

has mime_type => (
    is       => 'ro',
    isa      => NonEmptyStr,
    required => 1,
);

has charset => (
    is       => 'ro',
    isa      => NonEmptyStr,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_charset',
);

has _attributes => (
    traits   => ['Hash'],
    is       => 'ro',
    isa      => HashRef [NonEmptyStr],
    init_arg => 'attributes',
    default  => sub { {} },
    handles  => {
        attributes => 'elements',
        attribute  => 'get',
    },
);

sub _build_charset {
    my $self = shift;

    return $self->_attributes()->{charset} // 'us-ascii';
}

sub as_header_value {
    my $self = shift;

    my $string = $self->mime_type();

    my $attr = $self->_attributes();

    for my $k ( sort keys %{$attr} ) {
        my $val = quote_and_escape_attribute_value( $attr->{$k} );
        $string .= qq[; $k=$val];
    }

    return $string;
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: The content type for an email part

__END__

=head1 SYNOPSIS

    my $ct = $part->content_type();
    print $ct->mime_type();
    print $ct->charset();

    my %attr = $ct->attributes();
    while ( my ( $k, $v ) = each %attr ) {
        print "$k => $v\n";
    }

=head1 DESCRIPTION

This class represents the contents of a "Content-Type" header attached to an
email part. Such headers always include a mime type, and may also include
additional information such as a charset or other attributes.

Here are some typical headers:

  Content-Type: text/plain; charset=utf-8

  Content-Type: multipart/alternative; boundary=abcdefghijk

  Content-Type: image/jpeg; name="Filename.jpg"

=head1 API

This class supports the following methods:

=head2 Courriel::ContentType->new( ... )

This method creates a new object. It accepts the following parameters:

=over 4

=item * mime_type

A string like "text/plain" or "multipart/alternative". This is required.

=item * attributes

A hash reference of attributes from the header, such as a boundary, charset,
etc. This is optional, and can be empty.

=back

=head2 $ct->mime_type()

Returns the mime type value passed to the constructor.

=head2 $ct->charset()

Returns the charset for the content type.

This defaults to the value found in the C<attributes> or "us-ascii" as a
fallback.

=head2 $ct->attributes()

Returns a hash (not a reference) of the attributes passed to the constructor.

=head2 $ct->get_attribute($key)

Given a key, returns the value of the named attribute. Obviously, this value
can be C<undef> if the attribute doesn't exist.

=head2 $ct->as_header_value()

Returns the object as a string suitable for a header value (but not folded).
