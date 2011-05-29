use strict;
use warnings;

use Test::Fatal;
use Test::More 0.88;

use Courriel;

{
    my $text = <<'EOF';
Subject: Foo

This is the body
EOF

    my $email = Courriel->parse( text => \$text );

    is( $email->part_count(), 1, 'email has one part' );

    is_deeply(
        [ $email->headers()->headers() ],
        [ Subject => 'Foo' ],
        'headers were parsed correctly'
    );

    my ($part) = $email->parts();
    is(
        $part->content_type()->mime_type(),
        'text/plain',
        'email with no content type defaults to text/plain'
    );

    is(
        $part->content_type()->charset(),
        'us-ascii',
        'email with no charset defaults to us-ascii'
    );

    is(
        $part->encoding(),
        '8bit',
        'email with no encoding defaults to 8bit'
    );

    is_deeply(
        $part->content(),
        \$text,
        'content for part was parsed correctly'
    );

}

done_testing();
