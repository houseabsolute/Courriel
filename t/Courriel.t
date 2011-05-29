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

{
    my $text = <<'EOF';
From autarch@gmail.com Sun May 29 11:22:29 2011
MIME-Version: 1.0
Date: Sun, 29 May 2011 11:22:22 -0500
Message-ID: <BANLkTimjF2BDbOKO_2jFJsp6t+0KvqxCwQ@mail.gmail.com>
Subject: Testing
From: Dave Rolsky <autarch@gmail.com>
To: Dave Rolsky <autarch@urth.org>
Content-Type: multipart/alternative; boundary=20cf3071cfd06272ae04a46c9306


--20cf3071cfd06272ae04a46c9306
Content-Type: text/plain; charset=ISO-8859-1

This is a test email.

It has some *bold* text.

--20cf3071cfd06272ae04a46c9306
Content-Type: text/html; charset=ISO-8859-1

This is a test email.<br><br>It has some <b>bold</b> text.<br><br>

--20cf3071cfd06272ae04a46c9306--
EOF

    my $email = Courriel->parse( text => \$text );

    is( $email->part_count(), 2, 'email has two parts' );

    is_deeply(
        [ $email->headers()->headers() ],
        [
            'MIME-Version' => '1.0',
            'Date'         => 'Sun, 29 May 2011 11:22:22 -0500',
            'Message-ID' =>
                '<BANLkTimjF2BDbOKO_2jFJsp6t+0KvqxCwQ@mail.gmail.com>',
            'Subject' => 'Testing',
            'From'    => 'Dave Rolsky <autarch@gmail.com>',
            'To'      => 'Dave Rolsky <autarch@urth.org>',
            'Content-Type' =>
                'multipart/alternative; boundary=20cf3071cfd06272ae04a46c9306',
        ],
        'headers were parsed correctly'
    );

    my @parts = $email->parts();

    is(
        $parts[0]->content_type()->mime_type(),
        'text/plain',
        'first part is text/plain'
    );

    my $plain = <<'EOF';
This is a test email.

It has some *bold* text.

EOF

    is_deeply(
        $parts[0]->content(),
        \$plain,
        'plain content is as expected',
    );

    is(
        $parts[1]->content_type()->mime_type(),
        'text/html',
        'second part is text/html'
    );

    my $html = <<'EOF';
This is a test email.<br><br>It has some <b>bold</b> text.<br><br>

EOF

    is_deeply(
        $parts[1]->content(),
        \$html,
        'html content is as expected',
    );

}

done_testing();
