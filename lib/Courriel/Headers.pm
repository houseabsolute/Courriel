package Courriel::Headers;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Header;
use Courriel::Header::ContentType;
use Courriel::Header::Disposition;
use Courriel::Types
    qw( ArrayRef Defined HashRef HeaderArray NonEmptyStr Str Streamable StringRef );
use Encode qw( decode );
use MIME::Base64 qw( decode_base64 );
use MIME::QuotedPrint qw( decode_qp );
use MooseX::Params::Validate qw( pos_validated_list validated_list );
use Scalar::Util qw( blessed reftype );

use Moose;
use MooseX::StrictConstructor;

with 'Courriel::Role::Streams' => { -exclude => ['stream_to'] };

has _headers => (
    traits   => ['Array'],
    is       => 'ro',
    isa      => HeaderArray,
    default  => sub { [] },
    init_arg => 'headers',
    handles  => {
        headers => 'elements',
    },
);

# The _key_indices field, along with all the complicated code to
# get/add/remove headers below, is necessary because RFC 5322 says:
#
#   However, for the purposes of this specification, header fields SHOULD NOT
#   be reordered when a message is transported or transformed.  More
#   importantly, the trace header fields and resent header fields MUST NOT be
#   reordered, and SHOULD be kept in blocks prepended to the message.
#
# So we store headers as an array ref. When we add additional values for a
# header, we will put them after the last header of the same name in the array
# ref. If no such header exists yet, then we just put them at the end of the
# arrayref.

has _key_indices => (
    traits   => ['Hash'],
    isa      => HashRef [ ArrayRef [NonEmptyStr] ],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_key_indices',
    clearer  => '_clear_key_indices',
    handles  => {
        __key_indices_for => 'get',
    },
);

override BUILDARGS => sub {
    my $class = shift;

    my $p = super();

    return $p unless $p->{headers};

    # Could this be done as a coercion for the HeaderArray type? Maybe, but
    # it'd probably need structured types, which seems like as much of a
    # hassle as just doing this.
    if ( reftype( $p->{headers} ) eq 'ARRAY' ) {
        my $headers = $p->{headers};

        for ( my $i = 1 ; $i < @{$headers} ; $i += 2 ) {
            next if blessed( $headers->[ $i - 1 ] );

            my $name = $headers->[ $i - 1 ];

            next unless defined $name;

            $headers->[$i] = $class->_inflate_header( $name, $headers->[$i] );
        }
    }

    return $p;
};

sub _inflate_header {
    my $class = shift;
    my $name  = shift;
    my $value = shift;

    my ($header_class)
        = lc $name eq 'content-type'        ? 'Courriel::Header::ContentType'
        : lc $name eq 'content-disposition' ? 'Courriel::Header::Disposition'
        :                                     'Courriel::Header';

    return $header_class->new(
        name  => $name,
        value => $value,
    );
}

sub _build_key_indices {
    my $self = shift;

    my $headers = $self->_headers();

    my %indices;
    for ( my $i = 0; $i < @{$headers}; $i += 2 ) {
        push @{ $indices{ lc $headers->[$i] } }, $i + 1;
    }

    return \%indices;
}

{
    my @spec = ( { isa => NonEmptyStr } );

    sub get {
        my $self = shift;
        my ($name) = pos_validated_list(
            \@_,
            @spec,
        );

        return @{ $self->_headers() }[ $self->_key_indices_for($name) ];
    }
}

{
    my @spec = ( { isa => NonEmptyStr } );

    sub get_values {
        my $self = shift;
        my ($name) = pos_validated_list(
            \@_,
            @spec,
        );

        return
            map { $_->value() }
            @{ $self->_headers() }[ $self->_key_indices_for($name) ];
    }
}

sub _key_indices_for {
    my $self = shift;
    my $name = shift;

    return @{ $self->__key_indices_for( lc $name ) || [] };
}

{
    my @spec = (
        { isa => NonEmptyStr },
        { isa => Defined },
    );

    sub add {
        my $self = shift;
        my ( $name, $value ) = pos_validated_list(
            \@_,
            @spec,
        );

        my $headers = $self->_headers();

        my $last_index = ( $self->_key_indices_for($name) )[-1];

        my $header
            = blessed($value)
            && $value->isa('Courriel::Header')
            ? $value
            : $self->_inflate_header( $name, $value );

        if ($last_index) {
            splice @{$headers}, $last_index + 1, 0, ( $name => $header );
        }
        else {
            push @{$headers}, ( $name => $header );
        }

        $self->_clear_key_indices();

        return;
    }
}

{
    my @spec = (
        { isa => NonEmptyStr },
        { isa => Defined },
    );

    # Used to add things like Resent or Received headers
    sub unshift {
        my $self = shift;
        my ( $name, $value ) = pos_validated_list(
            \@_,
            { isa => NonEmptyStr },
            ( { isa => Defined } ) x ( @_ - 1 ),
            MX_PARAMS_VALIDATE_NO_CACHE => 1,
        );

        my $headers = $self->_headers();

        my $header
            = blessed($value)
            && $value->isa('Courriel::Header')
            ? $value
            : $self->_inflate_header( $name, $value );

        unshift @{$headers}, ( $name => $header );

        return;
    }
}

{
    my @spec = (
        { isa => NonEmptyStr },
    );

    sub remove {
        my $self = shift;
        my ($name) = pos_validated_list(
            \@_,
            @spec,
        );

        my $headers = $self->_headers();

        for my $idx ( reverse $self->_key_indices_for($name) ) {
            splice @{$headers}, $idx - 1, 2;
        }

        $self->_clear_key_indices();

        return;
    }
}

{
    my @spec = (
        { isa => NonEmptyStr },
        { isa => Defined },
    );

    sub replace {
        my $self = shift;
        my ( $name, $value ) = pos_validated_list(
            \@_,
            @spec,
        );

        $self->remove($name);
        $self->add( $name => $value );

        return;
    }
}

{
    my $horiz_ws = qr/[ \t]/;
    my $line_re  = qr/
                      (
                        [^\s:][^:\n\r]*       # a header name
                        :                     # followed by a colon
                        $horiz_ws*
                        .*                    # header value - can be empty
                      )
                      |
                      ($horiz_ws+(?:\S.*?))   # continuation line
                     /x;

    my @spec = (
        text => { isa => StringRef, coerce => 1 },
        line_sep =>
            { isa => NonEmptyStr, default => $Courriel::Helpers::CRLF },
    );

    sub parse {
        my $class = shift;
        my ( $text, $sep ) = validated_list(
            \@_,
            @spec,
        );

        my @raw_lines;

        my $sep_re = qr/\Q$sep/;

        $class->_maybe_fix_broken_headers( $text, $sep_re );

        while ( ${$text} =~ /\G${line_re}${sep_re}/gc ) {
            if ( defined $1 ) {
                push @raw_lines, $1;
            }
            else {
                die
                    'Header text contains a continuation line before a header name has been seen.'
                    unless @raw_lines;

                $raw_lines[-1] //= q{};
                $raw_lines[-1] .= $2;
            }
        }

        my $pos = pos ${$text} // 0;
        if ( $pos != length ${$text} ) {
            my @lines = split $sep_re, substr( ${$text}, 0, $pos );
            my $count = ( scalar @lines ) + 1;

            my $line = ( split $sep_re, ${$text} )[ $count - 1 ];

            die defined $line
                ? "Found an unparseable chunk in the header text starting at line $count:\n  $line"
                : 'Could not parse headers at all';
        }

        my @inflated
            = map { Courriel::Header->new_from_raw_line($_) } @raw_lines;

        return $class->new(
            headers => [ map { $_->name() => $_ } @inflated ] );
    }
}

sub _maybe_fix_broken_headers {
    my $class  = shift;
    my $text   = shift;
    my $sep_re = shift;

    # Some broken email messages have a newline in the headers that isn't
    # acting as a continuation, it's just an arbitrary line break. See
    # t/data/stress-test/mbox_mime_applemail_1xb.txt
    ${$text} =~ s/$sep_re([^\s:][^:]+$sep_re)/$1/g;

    return;
}

{
    my @spec = (
        output => { isa => Streamable, coerce => 1 },
        skip => { isa => ArrayRef [NonEmptyStr], default => [] },
        charset => { isa => NonEmptyStr, default => 'utf8' },
    );

    sub stream_to {
        my $self = shift;
        my ( $output, $skip, $charset ) = validated_list(
            \@_,
            @spec
        );

        my %skip = map { lc $_ => 1 } @{$skip};

        for my $header ( grep { blessed($_) } @{$self->_headers()} ) {
            next if $skip{ lc $header->name() };

            $header->stream_to( charset => $charset, output => $output );
        }

        return;
    }
}

sub as_string {
    my $self = shift;

    my $string = q{};

    $self->stream_to( output => $self->_string_output( \$string ), @_ );

    return $string;
}

sub _decode_one_word {
    my $self     = shift;
    my $charset  = shift;
    my $encoding = shift;
    my $content  = shift;

    if ( uc $encoding eq 'B' ) {
        return decode( $charset, decode_base64($content) );
    }
    else {
        $content =~ tr/_/ /;
        return decode( $charset, decode_qp($content) );
    }
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: The headers for an email part

__END__

=head1 SYNOPSIS

    my $email = Courriel->parse( text => ... );
    my $headers = $email->headers;

    print "$_\n" for $headers->get('Received');

=head1 DESCRIPTION

This class represents the headers of an email.

Any sub part of an email can have its own headers, so every part has an
associated object representing its headers. This class makes no distinction
between top-level headers and headers for a sub part.

Each individual header name/value pair is represented internally by a
L<Courriel::Header> object. Some headers have their own special
subclass. These are:

=over 4

=item * Content-Type

This is stored as a L<Courriel::Header::ContentType> object.

=item * Content-Disposition

This is stored as a L<Courriel::Header::Disposition> object.

=back

=head1 API

This class supports the following methods:

=head2 Courriel::Headers->parse( ... )

This method creates a new object by parsing a string. It accepts the following
parameters:

=over 4

=item * text

The text to parse. This can either be a plain scalar or a reference to a
scalar. If you pass a reference, the underlying scalar may be modified.

=item * line_sep

The line separator. This defaults to a "\r\n", but you can change it if
necessary.

=back

Header parsing unfolds folded headers, and decodes any MIME-encoded values as
described in RFC 2047. Parsing also decodes header attributes encoded as
described in RFC 2231.

=head2 Courriel::Headers->new( headers => [ ... ] )

This method creates a new object. It accepts one parameter, C<headers>, which
should be an array reference of header names and raw values.

The raw value for each header should include the entire header (name, colon,
whitespace, value, continuation lines).

A given header key can appear multiple times.
This object does not (yet, perhaps) enforce RFC restrictions on repetition of
certain headers.

Header order is preserved, per RFC 5322.

=head2 $headers->get($name)

Given a header name, this returns a list of the L<Courriel::Header> objects
found for the header. Each occurrence of the header is returned as a separate
object.

=head2 $headers->get_values($name)

Given a header name, this returns a list of the string values found for the
header. Each occurrence of the header is returned as a separate string.

=head2 $headers->add( $name => $value )

Given a header name and value, this adds the headers to the object. If any of
the headers already have values in the object, then new values are added after
the existing values, rather than at the end of headers.

The value can be provided as a string or a L<Courriel::Header> object.

=head2 $headers->unshift( $name => $value )

This is like C<add()>, but this pushes the headers onto the front of the
internal headers array. This is useful if you are adding "Received" headers,
which per RFC 5322, should always be added at the I<top> of the headers.

The value can be provided as a string or a L<Courriel::Header> object.

=head2 $headers->remove($name)

Given a header name, this removes all instances of that header from the object.

=head2 $headers->replace( $name => $value )

A shortcut for calling C<remove()> and C<add()>.

The value can be provided as a string or a L<Courriel::Header> object.

=head2 $headers->as_string( skip => ...., charset => ... )

This returns a string representing the headers in the object. The values will
be folded and/or MIME-encoded as needed.

The C<skip> parameter should be an array reference containing the name of
headers that should be skipped. This parameter is optional, and the default is
to include all headers.

The C<charset> parameter specifies what character set to use for MIME-encoding
non-ASCII values. This defaults to "utf8". The charset name must be one
recognized by the L<Encode> module.

MIME encoding is always done using the "B" (Base64) encoding, never the "Q"
encoding.

=head2 $headers->stream_to( output => $output, skip => ...., charset => ... )

This method will send the stringified headers to the specified output.

See the C<as_string()> method for documentation on the C<skip> and C<charset>
parameters.

=head1 ROLES

This class does the C<Courriel::Role::Streams> role.
