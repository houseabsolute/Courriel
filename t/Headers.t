use strict;
use warnings;

use Test::More 0.88;

use Courriel::Headers;

{
    my $h = Courriel::Headers->new();
    is_deeply(
        [ $h->headers() ],
        [],
        'can make an empty headers object'
    );

    $h->add( Subject => 'Foo bar' );

    is_deeply(
        [ $h->headers() ],
        [ Subject => 'Foo bar' ],
        'added Subject header'
    );

    is_deeply(
        [ $h->get('subject') ],
        [ 'Foo bar' ],
        'got subject header (name is case-insensitive)'
    );

    $h->add( 'Content-Type' => 'text/plain' );

    is_deeply(
        [ $h->headers() ],
        [
            Subject        => 'Foo bar',
            'Content-Type' => 'text/plain',
        ],
        'added Content-Type header'
    );

    $h->add( 'Subject' => 'Part 2' );

    is_deeply(
        [ $h->headers() ],
        [
            Subject        => 'Foo bar',
            Subject        => 'Part 2',
            'Content-Type' => 'text/plain',
        ],
        'added another subject header and it shows up after first subject'
    );

    is_deeply(
        [ $h->get('subject') ],
        [ 'Foo bar', 'Part 2' ],
        'got all subject headers'
    );

    $h->remove('Subject');

    is_deeply(
        [ $h->headers() ],
        [
            'Content-Type' => 'text/plain',
        ],
        'removed Subject headers'
    );
}

my $crlf = "\x0d\x0a";

{
    my $simple = <<'EOF';
Foo: 1
Bar: 2
Baz: 3
EOF

    $simple =~ s/\n/$crlf/g;

    my $h = Courriel::Headers->parse( text => \$simple, line_sep => $crlf );

    is_deeply(
        [ $h->headers() ],
        [
            Foo => 1,
            Bar => 2,
            Baz => 3,
        ],
        'parsed simple headers'
    );
}

{
    my $simple = <<'EOF';
Foo: 1
Bar: 2
Baz: 3
Bar: 4
EOF

    $simple =~ s/\n/$crlf/g;

    my $h = Courriel::Headers->parse( text => \$simple, line_sep => $crlf );

    is_deeply(
        [ $h->headers() ],
        [
            Foo => 1,
            Bar => 2,
            Baz => 3,
            Bar => 4,
        ],
        'parsed headers with repeated value'
    );
}

{
    my $simple = <<'EOF';
Foo: hello
  world
Bar: 2
Baz: 3
EOF

    $simple =~ s/\n/$crlf/g;

    my $h = Courriel::Headers->parse( text => \$simple, line_sep => $crlf );

    is_deeply(
        [ $h->headers() ],
        [
            Foo => 'hello world',
            Bar => 2,
            Baz => 3,
        ],
        'parsed headers with continuation line'
    );
}

{
    my $simple = <<'EOF';
Foo: 1
Bar: 2
Baz: 3
EOF

    my $h = Courriel::Headers->parse( text => \$simple, line_sep => "\n" );

    is_deeply(
        [ $h->headers() ],
        [
            Foo => 1,
            Bar => 2,
            Baz => 3,
        ],
        'parsed headers with newline as line separator'
    );
}

done_testing();
