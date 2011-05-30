package Courriel;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::ContentType;
use Courriel::Headers;
use Courriel::Part::Multipart;
use Courriel::Part::Single;
use Courriel::Types qw( Bool Headers Part StringRef );
use Email::MIME::ContentType qw( parse_content_type );
use MooseX::Params::Validate qw( validated_list );

use Moose;

has _part => (
    is       => 'ro',
    isa      => Part,
    init_arg => 'part',
    required => 1,
    handles  => [
        qw(
            content_type
            headers
            is_multipart
            )
    ]
);

sub part_count {
    my $self = shift;

    return $self->is_multipart()
        ? $self->_part()->part_count()
        : 1;
}

sub parts {
    my $self = shift;

    return $self->is_multipart()
        ? $self->_part()->parts()
        : $self->_part();
}

# from Email::Simple
my $LINE_SEP_RE = qr/\x0a\x0d|\x0d\x0a|\x0a|\x0d/;

{
    my @spec = ( text => { isa => StringRef, coerce => 1 } );

    sub parse {
        my $class = shift;
        my ($text) = validated_list(
            \@_,
            @spec,
        );

        return $class->new( part => $class->_parse($text) );
    }
}

sub _parse {
    my $class = shift;
    my $text  = shift;

    my ( $line_sep, $sep_idx, $headers ) = $class->_parse_headers($text);

    substr( ${$text}, 0, $sep_idx ) = q{};

    return $class->_parse_parts( $text, $headers );
}

sub _parse_headers {
    my $class = shift;
    my $text  = shift;

    my $header_text;
    my $sep_idx;
    my $line_sep;

    # We want to ignore mbox message separators
    ${$text} =~ s/^From .+ \d\d:\d\d:\d\d \d\d\d\d$LINE_SEP_RE//;

    if ( ${$text} =~ /(.+?)($LINE_SEP_RE)\2/s ) {
        $header_text = $1 . $2;
        $sep_idx     = ( length $header_text ) + ( length $2 );
        $line_sep    = $2;
    }
    else {
        die
            'The text you passed to parse() does not appear to be a valid email.';
    }

    # Need to quote class name or else this perl sees this as
    # Courriel::Headers() because of the Headers type constraint.
    my $headers = 'Courriel::Headers'->parse(
        text     => \$header_text,
        line_sep => $line_sep,
    );

    return ( $line_sep, $sep_idx, $headers );
}

sub _parse_parts {
    my $class     = shift;
    my $text      = shift;
    my $headers   = shift;

    my @ct = $headers->get('Content-Type');
    if ( @ct > 1 ) {
        die 'This email defines more than one content-type header.';
    }

    my $parsed_ct = parse_content_type( $ct[0] // 'text/plain' );

    my $ct = 'Courriel::ContentType'->new(
        mime_type => "$parsed_ct->{discrete}/$parsed_ct->{composite}",
        (
            $parsed_ct->{attributes}{charset}
            ? ( charset => $parsed_ct->{attributes}{charset} )
            : ()
        ),
        attributes => $parsed_ct->{attributes},
    );

    if ( $ct->mime_type() !~ /^multipart/ ) {
        return Courriel::Part::Single->new(
            content_type => $ct,
            headers      => $headers,
            raw_content  => $text,
        );
    }

    my $boundary = $ct->{attributes}{boundary}
        // die q{The message's mime type claims this is a multipart message (}
        . $ct->mime_type()
        . q{) but it does not specify a boundary.};

    my ( $preamble, $all_parts, $epilogue ) = ${$text} =~ /
                (.*?)                   # preamble
                ^--\Q$boundary\E\s*
                (.+)                    # all parts
                ^--\Q$boundary\E--\s*
                (.*)                    # epilogue
                /smx;

    my @part_text = split /^--\Q$boundary\E\s*/m, $all_parts;

    die 'Could not parse any parts from a supposedly multipart message.'
        unless @part_text;

    return Courriel::Part::Multipart->new(
        content_type => $ct,
        headers      => $headers,
        (
                   defined $preamble
                && length $preamble
                && $preamble =~ /\S/ ? ( preamble => $preamble ) : ()
        ),
        (
                   defined $epilogue
                && length $epilogue
                && $epilogue =~ /\S/ ? ( epilogue => $epilogue ) : ()
        ),
        boundary => $boundary,
        parts    => [ map { $class->_parse( \$_ ) } @part_text ],
    );
}

__PACKAGE__->meta()->make_immutable();

1;
