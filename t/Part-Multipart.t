use strict;
use warnings;

use Test::More 0.88;

use Courriel::ContentType;
use Courriel::Headers;
use Courriel::Part::Multipart;

my $crlf = "\x0d\x0a";

{
    my $headers = Courriel::Headers->new( headers => [] );

    my $part = Courriel::Part::Multipart->new(
        headers  => $headers,
        boundary => 'foo',
        parts    => [],
    );

    is_deeply(
        { $part->content_type()->attributes() },
        { boundary => 'foo' },
        'setting a multipart boundary in the constructor also sets it in the ContentType object later'
    );
}

{
    my $headers = Courriel::Headers->new( headers => [] );
    my $ct = Courriel::ContentType->new( mime_type => 'multipart/mixed' );

    my $part = Courriel::Part::Multipart->new(
        headers      => $headers,
        content_type => $ct,
        boundary     => 'foo',
        parts        => [],
    );

    is_deeply(
        { $part->content_type()->attributes() },
        { boundary => 'foo' },
        'setting a multipart boundary in the constructor also sets it in the ContentType passed to the constructor'
    );
}

{
    my $headers = Courriel::Headers->new( headers => [] );

    my $part = Courriel::Part::Multipart->new(
        headers => $headers,
        parts   => [],
    );

    my $boundary = $part->boundary();

    is_deeply(
        { $part->content_type()->attributes() },
        { boundary => $boundary },
        'when a boundary is built lazily, it is also set in the content type object'
    );
}

{
    my $headers = Courriel::Headers->new( headers => [] );

    my $part = Courriel::Part::Multipart->new(
        headers => $headers,
        parts   => [],
    );

    my $ct       = $part->content_type();
    my $boundary = $part->boundary();

    is_deeply(
        { $part->content_type()->attributes() },
        { boundary => $boundary },
        'when a content type is built lazily, it gets the boundary when that is built'
    );
}

done_testing();
