use strict;
use warnings;

use utf8;

use Test::Fatal;
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
    my $headers = <<'EOF';
Foo: 1
Bar: 2
Baz: 3
EOF

    $headers =~ s/\n/$crlf/g;

    my $h = Courriel::Headers->parse( text => \$headers, line_sep => $crlf );

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
    my $headers = <<'EOF';
Foo: 1
Bar: 2
Baz: 3
Bar: 4
EOF

    $headers =~ s/\n/$crlf/g;

    my $h = Courriel::Headers->parse( text => \$headers, line_sep => $crlf );

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
    my $headers = <<'EOF';
Foo: hello
  world
Bar: 2
Baz: 3
EOF

    $headers =~ s/\n/$crlf/g;

    my $h = Courriel::Headers->parse( text => \$headers, line_sep => $crlf );

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
    my $headers = <<'EOF';
Subject: =?iso-8859-1?Q?=A1Hola,_se=F1or!?=
Bar: 2
Baz: 3
EOF

    my $h = Courriel::Headers->parse( text => \$headers, line_sep => "\n" );

    is_deeply(
        [ $h->headers() ],
        [
            Subject => "¡Hola, señor!",
            Bar     => 2,
            Baz     => 3,
        ],
        'parsed headers with MIME encoded value'
    );
}

{
    my $real = <<'EOF';
Return-Path: <rtcpan@cpan.rt.develooper.com>
X-Spam-Checker-Version: SpamAssassin 3.3.1 (2010-03-16) on urth.org
X-Spam-Level: 
X-Spam-Status: No, score=-6.9 required=5.0 tests=BAYES_00,RCVD_IN_DNSWL_HI,
    T_RP_MATCHES_RCVD autolearn=ham version=3.3.1
X-Original-To: autarch@urth.org
Delivered-To: autarch@urth.org
Received: from localhost (localhost.localdomain [127.0.0.1])
    by urth.org (Postfix) with ESMTP id BDC8B171751
    for <autarch@urth.org>; Sat, 28 May 2011 12:54:18 -0500 (CDT)
X-Virus-Scanned: Debian amavisd-new at urth.org
Received: from urth.org ([127.0.0.1])
    by localhost (urth.org [127.0.0.1]) (amavisd-new, port 10024)
    with ESMTP id YITg-uxEcP1N for <autarch@urth.org>;
    Sat, 28 May 2011 12:54:10 -0500 (CDT)
Received: from x1.develooper.com (x1.develooper.com [207.171.7.70])
    by urth.org (Postfix) with SMTP id D312D1707FC
    for <autarch@urth.org>; Sat, 28 May 2011 12:54:09 -0500 (CDT)
Received: (qmail 26426 invoked by uid 225); 28 May 2011 17:54:08 -0000
Delivered-To: DROLSKY@cpan.org
Received: (qmail 26422 invoked by uid 103); 28 May 2011 17:54:08 -0000
Received: from x16.dev (10.0.100.26)
  by x1.dev with QMQP; 28 May 2011 17:54:08 -0000
Received: from cpan.rt.develooper.com (HELO cpan.rt.develooper.com) (207.171.7.181)
    by 16.mx.develooper.com (qpsmtpd/0.80/v0.80-19-gf52d165) with ESMTP; Sat, 28 May 2011 10:54:05 -0700
Received: by cpan.rt.develooper.com (Postfix, from userid 536)
    id 7E07B704A; Sat, 28 May 2011 10:54:03 -0700 (PDT)
Precedence: normal
Subject: [rt.cpan.org #68527] [PATCH] add a 'end_of_life' optional deprecation parameter 
From: "Yanick Champoux via RT" <bug-Package-DeprecationManager@rt.cpan.org>
Reply-To: bug-Package-DeprecationManager@rt.cpan.org
In-Reply-To: <1306605315-23916-1-git-send-email-yanick@cpan.org>
References: <RT-Ticket-68527@rt.cpan.org> <1306605315-23916-1-git-send-email-yanick@cpan.org>
Message-ID: <rt-3.8.HEAD-18810-1306605243-528.68527-4-0@rt.cpan.org>
X-RT-Loop-Prevention: rt.cpan.org
RT-Ticket: rt.cpan.org #68527
Managed-by: RT 3.8.HEAD (http://www.bestpractical.com/rt/)
RT-Originator: yanick@cpan.org
MIME-Version: 1.0
Content-Transfer-Encoding: 8bit
Content-Type: text/plain; charset="utf-8"
X-RT-Original-Encoding: utf-8
Date: Sat, 28 May 2011 13:54:03 -0400
To: undisclosed-recipients:;
EOF

    $real =~ s/\n/$crlf/g;

    my $h = Courriel::Headers->parse( text => \$real, line_sep => $crlf );

    is(
        $h->get('Precedence'), 'normal',
        'Precendence header was parsed properly'
    );

    is(
        $h->get('Message-ID'),
        '<rt-3.8.HEAD-18810-1306605243-528.68527-4-0@rt.cpan.org>',
        'Message-ID header was parsed properly'
    );

    is(
        $h->get('X-Spam-Level'),
        q{},
        'X-Spam-Level (empty header) was parsed properly',
    );

    is(
        $h->get('X-Spam-Status'),
        'No, score=-6.9 required=5.0 tests=BAYES_00,RCVD_IN_DNSWL_HI, T_RP_MATCHES_RCVD autolearn=ham version=3.3.1',
        'X-Spam-Status header was parsed properly'
    );
}

{
    my $bad = <<'EOF';
Ok: 1
: bad
EOF

    like(
        exception {
            Courriel::Headers->parse(
                text     => \$bad,
                line_sep => "\n",
            );
        },
        qr/Found an unparseable .+ at line 2/,
        'exception on bad headers'
    );
}

{
    my $bad = <<'EOF';
Ok: 1
Ok: 2
Not ok
Ok: 4
EOF

    like(
        exception {
            Courriel::Headers->parse(
                text     => \$bad,
                line_sep => "\n",
            );
        },
        qr/Found an unparseable .+ at line 3/,
        'exception on bad headers'
    );
}

{
    # Second line has spaces
    my $bad = <<'EOF';
Ok: 1
  
Ok: 2
EOF

    like(
        exception {
            Courriel::Headers->parse(
                text     => \$bad,
                line_sep => "\n",
            );
        },
        qr/Found an unparseable .+ at line 2/,
        'exception on bad headers'
    );
}

done_testing();
