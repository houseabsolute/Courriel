package Courriel::Headers;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Helpers qw( fold_header );
use Courriel::Types
    qw( ArrayRef Defined EvenArrayRef HashRef NonEmptyStr Str StringRef );
use Encode qw( decode encode find_encoding );
use MIME::Base64 qw( decode_base64 encode_base64 );
use MIME::QuotedPrint qw( decode_qp );
use MooseX::Params::Validate qw( pos_validated_list validated_list );

use Moose;
use MooseX::StrictConstructor;

has _headers => (
    traits   => ['Array'],
    is       => 'ro',
    isa      => EvenArrayRef [Str],
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
        my ($key) = pos_validated_list(
            \@_,
            @spec,
        );

        return @{ $self->_headers() }[ $self->_key_indices_for($key) ];
    }
}

sub _key_indices_for {
    my $self = shift;
    my $key  = shift;

    return @{ $self->__key_indices_for( lc $key ) || [] };
}

{
    my @spec = (
        { isa => NonEmptyStr },
        { isa => Defined },
    );

    sub add {
        my $self = shift;
        my ( $key, $val ) = pos_validated_list(
            \@_,
            @spec,
        );

        my $headers = $self->_headers();

        my $last_index = ( $self->_key_indices_for($key) )[-1];

        if ($last_index) {
            splice @{$headers}, $last_index + 1, 0, ( $key => $val );
        }
        else {
            push @{$headers}, ( $key => $val );
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
        my ( $key, $val ) = pos_validated_list(
            \@_,
            { isa => NonEmptyStr },
            ( { isa => Defined } ) x ( @_ - 1 ),
            MX_PARAMS_VALIDATE_NO_CACHE => 1,
        );

        my $headers = $self->_headers();

        unshift @{$headers}, ( $key => $val );

        return;
    }
}

{
    my @spec = (
        { isa => NonEmptyStr },
    );

    sub remove {
        my $self = shift;
        my ($key) = pos_validated_list(
            \@_,
            @spec,
        );

        my $headers = $self->_headers();

        for my $idx ( reverse $self->_key_indices_for($key) ) {
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
        my ( $key, $val ) = pos_validated_list(
            \@_,
            @spec,
        );

        $self->remove($key);
        $self->add( $key => $val );

        return;
    }
}

{
    my $horiz_ws = qr/[ \t]/;
    my $line_re  = qr/
                      (?:
                          ([^\s:][^:\n\r]*)  # a header name
                          :                  # followed by a colon
                          $horiz_ws*
                          (.*)               # header value - can be empty
                      )
                      |
                      $horiz_ws+(\S.*)?      # continuation line
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

        my @headers;

        my $sep_re = qr/\Q$sep/;

        $class->_maybe_fix_broken_headers( $text, $sep_re );

        while ( ${$text} =~ /\G${line_re}${sep_re}/gc ) {
            if ( defined $1 ) {
                push @headers, $1, $2;
            }
            else {
                die
                    'Header text contains a continuation line before a header name has been seen.'
                    unless @headers;

                $headers[-1] //= q{};

                # Looking at RFC 5322 it really seems like the whitespace on
                # the continuation line should be part of the header value,
                # but looking at emails in real use suggests that all the
                # leading whitespace should be compressed down to a single
                # space, so that's what we do.
                $headers[-1] .= q{ } if length $headers[-1];
                $headers[-1] .= $3 if defined $3;
            }
        }

        my $pos = pos ${$text} // 0;
        if ( $pos != length ${$text} ) {
            my @lines = split $sep_re, substr( ${$text}, 0, $pos );
            my $count = ( scalar @lines ) + 1;

            my $line = ( split $sep_re, ${$text} )[ $count - 1 ];

            die
                "Found an unparseable chunk in the header text starting at line $count:\n  $line";
        }

        for ( my $i = 1; $i < @headers; $i += 2 ) {
            $headers[$i] = $class->_mime_decode( $headers[$i] );
        }

        return $class->new( headers => \@headers );
    }
}

sub _maybe_fix_broken_headers {
    my $class  = shift;
    my $text   = shift;
    my $sep_re = shift;

    # Some broken email messages have a newline int he headers that isn't
    # acting as a continuation, it's just an arbitrary line break. See
    # t/data/stress-test/mbox_mime_applemail_1xb.txt
    ${$text} =~ s/$sep_re([^\s:][^:]+$sep_re)/$1/g;

    return;
}

{
    my @spec = (
        skip => { isa => ArrayRef [NonEmptyStr], default => [] },
        charset => { isa => NonEmptyStr, default => 'utf8' },
    );

    sub as_string {
        my $self = shift;
        my ( $skip, $charset ) = validated_list(
            \@_,
            @spec
        );

        my %skip = map { lc $_ => 1 } @{$skip};

        my $string = q{};

        my $headers = $self->_headers();

        for ( my $i = 0; $i < @{$headers}; $i += 2 ) {
            next if $skip{ lc $headers->[$i] };

            my $value = $headers->[ $i + 1 ];

            $value = $self->_mime_encode( $value, $charset )
                unless $value =~ /^[\x20-\x7e]+$/;

            $string .= fold_header( $headers->[$i] . ': ' . $value );
        }

        return $string;
    }
}

{
    my $mime_word = qr/
                      (?:
                          =\?                         # begin encoded word
                          (?<charset>[-0-9A-Za-z_]+)  # charset (encoding)
                          (?:\*[A-Za-z]{1,8}(?:-[A-Za-z]{1,8})*)? # language (RFC 2231)
                          \?
                          (?<encoding>[QqBb])         # encoding type
                          \?
                          (?<content>.*?)             # Base64-encoded contents
                          \?=                         # end encoded word
                          |
                          (?<unencoded>\S+)
                      )
                      (?<ws>[ \t]+)?
                      /x;

    sub _mime_decode {
        my $self = shift;
        my $text = shift;

        return $text unless $text =~ /=\?[\w-]+\?[BQ]\?/i;

        my @chunks;

        # If a MIME encoded word is followed by _another_ such word, we ignore any
        # intervening whitespace, otherwise we preserve the whitespace between a
        # MIME encoded word and an unencoded word. See RFC 2047 for details on
        # this.
        while ( $text =~ /\G$mime_word/g ) {
            if ( defined $+{charset} ) {
                push @chunks, {
                    content => $self->_decode_one_word(
                        @+{ 'charset', 'encoding', 'content' }
                    ),
                    ws      => $+{ws},
                    is_mime => 1,
                    };
            }
            else {
                push @chunks, {
                    content => $+{unencoded},
                    ws      => $+{ws},
                    is_mime => 0,
                    };
            }
        }

        my $result = q{};

        for my $i ( 0 .. $#chunks ) {
            $result .= $chunks[$i]{content};
            $result .= ( $chunks[$i]{ws} // q{} )
                unless $chunks[$i]{is_mime}
                    && $chunks[ $i + 1 ]
                    && $chunks[ $i + 1 ]{is_mime};
        }

        return $result;
    }
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

sub _mime_encode {
    my $self    = shift;
    my $text    = shift;
    my $charset = find_encoding(shift)->mime_name();

    my $head = '=?' . $charset . '?B?';
    my $tail = '?=';

    my $base_length = 75 - ( length($head) + length($tail) );

    # This code is copied from Mail::Message::Field::Full in the Mail-Box
    # distro.
    my $real_length = int( $base_length / 4 ) * 3;

    my @result;
    my $chunk = q{};
    while ( length( my $chr = substr( $text, 0, 1, '' ) ) ) {
        my $chr = encode( $charset, $chr, 0 );

        if ( length($chunk) + length($chr) > $real_length ) {
            push @result, $head . encode_base64( $chunk, q{} ) . $tail;
            $chunk = q{};
        }

        $chunk .= $chr;
    }

    push @result, $head . encode_base64( $chunk, q{} ) . $tail
        if length $chunk;

    return join q{ }, @result;
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

The line separator. This default to a "\r\n", but you can change it if
necessary. Note that this only affects parsing, header objects are always
output with RFC-compliant line endings.

=back

Header parsing unfolds folded headers, and decodes any MIME-encoded values (as
described in RFC 2047).

=head2 Courriel::Headers->new( headers => [ ... ] )

This method creates a new object. It accepts one parameter, C<headers>, which
should be an array reference of header names and values.

A given header key can appear multiple times.

This object does not (yet, perhaps) enforce RFC restrictions on repetition of
certain headers.

Header order is preserved, per RFC 5322.

=head2 $headers->get($name)

Given a header name, this returns a list of the values found for the
header. Each occurrence of the header is returned as a separate value.

=head2 $headers->add( $name => $value )

Given a header name and value, this adds the headers to the object. If any of
the headers already have values in the object, then new values are added after
the existing values, rather than at the end of headers.

=head2 $headers->unshift( $name => $value )

This is like C<add()>, but this pushes the headers onto the front of the
internal headers array. This is useful if you are adding "Received" headers,
which per RFC 5322, should always be added at the I<top> of the headers.

=head2 $headers->remove($name)

Given a header name, this removes all instances of that header from the object.

=head2 $headers->replace( $name => $value )

A shortcut for calling C<remove()> and C<add()>.

=head2 $headers->as_string( charset => ... )

This returns a string representing the headers in the object. The values will
be folded and/or MIME-encoded as needed.

The C<charset> parameter specifies what character set to use for MIME-encoding
non-ASCII values. This defaults to "utf8". The charset name must be one
recognized by the L<Encode> module.

MIME encoding is always done using the "B" (Base64) encoding, never the "Q"
encoding.
