package Courriel::Header;

use strict;
use warnings;
use namespace::autoclean;

use Carp qw( confess );
use Courriel::Helpers qw( fold_header );
use Courriel::Types qw( NonEmptyStr Str Streamable );
use Encode qw( encode find_encoding );
use MIME::Base64 qw( encode_base64 );
use MooseX::Params::Validate qw( validated_list );

use Moose;
use MooseX::StrictConstructor;

with 'Courriel::Role::Streams' => { -exclude => ['stream_to'] };

has name => (
    is       => 'ro',
    isa      => NonEmptyStr,
    required => 1,
);

has value => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_value',
);

has raw_header => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_raw_header',
);

sub BUILD {
    my $self = shift;
    my $p    = shift;

    confess
        'You must provide a value or raw_header parameter when creating a header'
        unless defined $p->{value} || defined $p->{raw_header};

    return;
}

{
    my @spec = (
        output => { isa => Streamable, coerce => 1 },
    );

    sub stream_to {
        my $self = shift;
        my ($output) = validated_list(
            \@_,
            @spec
        );

        $output->( $self->raw_header() );

        return;
    }
}

sub as_string {
    my $self = shift;

    my $string = q{};

    $self->stream_to( output => $self->_string_output( \$string ), @_ );

    return $string;
}

sub _build_value {
    my $self = shift;

    my $raw = $self->raw_header();

    my ( $first, @rest ) = split /\r\n|\r|\n/, $raw;

    $first =~ /^[^\s:][^:\n\r]*:\s*(.+)$/;

    my $value = $1;

    # RFC 5322 says:
    #
    #   Runs of FWS, comment, or CFWS that occur between lexical tokens in a
    #   structured header field are semantically interpreted as a single
    #   space character.
    for my $line (@rest) {
        $line =~ s/^\s+/ /;
        $value .= $line;
    }

    return $self->_mime_decode($value);
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
                push @chunks,
                    {
                    content => $self->_decode_one_word(
                        @+{ 'charset', 'encoding', 'content' }
                    ),
                    ws      => $+{ws},
                    is_mime => 1,
                    };
            }
            else {
                push @chunks,
                    {
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

sub _build_raw_header {
    my $self = shift;

    my $raw = $self->name();
    $raw .= ': ';

    $raw .= $self->_maybe_encoded_value();

    return fold_header($raw);
}

{
    my $header_chunk = qr/
                             (?:
                                 (?<ascii>[\x21-\x7e]+)   # printable ASCII (excluding space, \x20)
                             |
                                 (?<non_ascii>\S+)        # anything that's not space
                             )
                             (?:
                                 (?<ws>\s+)
                             |
                                 $
                             )
                         /x;

    # XXX - this really isn't very correct. Only certain types of values (per RFC
    # 2047) can be encoded, not just any random text. I'm not sure how best to
    # handle this. If we parsed an email that encoded stuff that shouldn't be
    # encoded, what should we do? At the very least, we should add some checks to
    # Courriel::Builder to ensure that people don't try to create an email with
    # non-ASCII in certain parts of fields (like in email addresses).
    sub _maybe_encoded_value {
        my $self = shift;

        my $value = $self->value();
        my @chunks;

        while ( $value =~ /\G$header_chunk/g ) {
            push @chunks, {%+};
        }

        my @values;
        for my $i ( 0 .. $#chunks ) {
            if ( defined $chunks[$i]->{non_ascii} ) {
                my $to_encode
                    = $chunks[ $i + 1 ]
                    && defined $chunks[ $i + 1 ]{non_ascii}
                    ? $chunks[$i]{non_ascii} . ( $chunks[$i]{ws} // q{} )
                    : $chunks[$i]{non_ascii};

                push @values, $self->_mime_encode($to_encode);
                push @values, q{ } if $chunks[ $i + 1 ];
            }
            else {
                push @values, $chunks[$i]{ascii} . ( $chunks[$i]{ws} // q{} );
            }
        }

        return join q{}, @values;
    }
}

sub _mime_encode {
    my $self = shift;
    my $text = shift;

    my $head = '=?UTF-8?B?';
    my $tail = '?=';

    my $base_length = 75 - ( length($head) + length($tail) );

    # This code is copied from Mail::Message::Field::Full in the Mail-Box
    # distro.
    my $real_length = int( $base_length / 4 ) * 3;

    my @result;
    my $chunk = q{};
    while ( length( my $chr = substr( $text, 0, 1, '' ) ) ) {
        my $chr = encode( 'UTF-8', $chr, 0 );

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

# ABSTRACT: A single header's name and value

__END__

=head1 SYNOPSIS

  my $subject = $headers->get('subject');
  print $subject->value();

=head1 DESCRIPTION

This class represents a single header, which consists of a name and value.

=head1 API

This class supports the following methods:

=head1 Courriel::Header->new( ... )

This method requires two attributes, C<name> and C<value>. Both must be
strings. The C<name> cannot be empty, but the C<value> can.

=head2 $header->name()

The header name as passed to the constructor.

=head2 $header->value()

The header value as passed to the constructor.

=head2 $header->raw_header()

The full header, encoded and folded as needed. If this header was created by
parsing an email, this will return the header as it was in the original, byte
for byte.

=head2 $header->as_string()

Returns the header name and value with any necessary MIME encoding and
folding. If MIME encoding is needed it will be done with the C<utf8> encoding.

If this header was created with a raw header, then that will be returned as
is.

=head2 $header->stream_to( output => $output )

This method will send the stringified header to the specified output. The
output can be a subroutine reference, a filehandle, or an object with a
C<print()> method. The output may be sent as a single string, as a list of
strings, or via multiple calls to the output.

See the C<as_string()> method for documentation on the C<charset> parameter.

=head1 ROLES

This class does the C<Courriel::Role::Streams> role.
