package Courriel;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::ContentType;
use Courriel::Headers;
use Courriel::Part::Multipart;
use Courriel::Part::Single;
use Courriel::Types qw( Bool Headers StringRef );
use Email::MIME::ContentType qw( parse_content_type );
use MooseX::Params::Validate qw( validated_list );

use Moose;

with 'Courriel::Role::HasParts', 'Courriel::Role::HasContentType';

has headers => (
    is       => 'ro',
    isa      => Headers,
    required => 1,
);

override BUILDARGS => sub {
    my $class = shift;

    my $p = super();

    if ( exists $p->{part} ) {
        my $part = delete $p->{part};

        $p->{parts} = [$part]
            unless exists $p->{parts};
    }

    return $p;
};

sub _build_content_type {
    my $self = shift;

    if ( @{ $self->parts() } == 1 ) {
        return $self->parts()->[0]->content_type();
    }
    else {
        return 'multipart/mixed';
    }
}

# from Email::Simple
my $LINE_SEP_RE = qr/\x0a\x0d|\x0d\x0a|\x0a|\x0d/;

sub parse {
    my $class = shift;

    my ( $headers, $part ) = $class->_parse(@_);

    my @parts
        = $part->is_multipart()
        ? $part->parts()
        : $part;

    return $class->new(
        headers => $headers,
        parts   => \@parts,
    );
}

sub _parse {
    my $class = shift;
    my ($text) = validated_list(
        \@_,
        text => { isa => StringRef, coerce => 1 },
    );

    my ( $line_sep, $sep_idx, $headers ) = $class->_parse_headers($text);

    substr( ${$text}, 0, $sep_idx ) = q{};

    my $part = $class->_parse_parts( $text, $headers );

    return ( $headers, $part );
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

    my @parts = map {
        my ( undef, $part ) = $class->_parse( text => \$_ );
        $part;
    } @part_text;

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
        parts    => \@parts,
    );
}

__PACKAGE__->meta()->make_immutable();

1;
