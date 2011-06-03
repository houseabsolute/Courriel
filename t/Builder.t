use strict;
use warnings;

use Test::Fatal;
use Test::More 0.88;

use Courriel::Builder;

{
    my $email = build_email(
        subject('Test Subject'),
        from('autarch@urth.org'),
        to( 'autarch@urth.org', Email::Address->parse('bob@example.com') ),
        cc( 'jane@example.com', Email::Address->parse('joe@example.com') ),
        bcc( 'alice@example.com', Email::Address->parse('adam@example.com') ),
        header( 'X-Foo' => 42 ),
        header( 'X-Bar' => 84 ),
        plain_body('The body of the message')
    );

    isa_ok( $email, 'Courriel' );

    my %expect = (
        Subject        => 'Test Subject',
        From           => 'autarch@urth.org',
        To             => 'autarch@urth.org, bob@example.com',
        Cc             => 'jane@example.com, joe@example.com',
        Bcc            => 'alice@example.com, adam@example.com',
        'X-Foo'        => '42',
        'X-Bar'        => 84,
        'Content-Type' => 'text/plain; charset=UTF-8',
    );

    for my $key ( sort keys %expect ) {
        is_deeply(
            [ $email->headers()->get($key) ],
            [ $expect{$key} ],
            "got expected value for $key header"
        );
    }

    my @date = $email->headers()->get('Date');
    is( scalar @date, 1, 'found one Date header' );
    like(
        $date[0],
        qr/\w\w\w, \d\d \w\w\w \d\d\d\d \d\d:\d\d:\d\d [-+]\d\d\d\d/,
        'Date header looks like a proper date'
    );

    my @id = $email->headers()->get('Message-Id');
    is( scalar @id, 1, 'found one Message-Id header' );
    like(
        $id[0],
        qr/<[^>]+>/,
         'Message-Id is in brackets'
    );
}

{
    my $email = build_email(
        subject('Test Subject'),
        plain_body(
            content => 'Foo',
            charset => 'ISO-8859-1'
        ),
    );

    my @ct = $email->headers()->get('Content-Type');
    is( scalar @ct, 1, 'found one Content-Type header' );
    is(
        $ct[0],
        'text/plain; charset=ISO-8859-1',
        'Content-Type has the right charset'
    );
}

{
    my $dt = DateTime->new( year => 1980, time_zone => 'UTC' );

    my $email = build_email(
        subject('Test Subject'),
        header( Date => DateTime::Format::Mail->format_datetime($dt) ),
        plain_body( content => 'Foo' ),
    );

    my @date = $email->headers()->get('Date');
    is( scalar @date, 1, 'found one Date header' );
    is(
        $date[0],
        'Tue, 01 Jan 1980 00:00:00 -0000',
        'explicit Date header is not overwritten'
    );
}

{
    my $email = build_email(
        subject('Test Subject'),
        plain_body(
            content => "Foo \x{00F1}",
            encoding => 'quoted-printable'
        ),
    );

    like(
        ${ $email->plain_body_part()->encoded_content() },
        qr/=F1/,
        'body is encoded using quoted-printable'
    );
}

{
    like(
        exception { build_email( ['wtf'] ); },
        qr/A weird value was passed to build_email:/,
        'got error when passing invalid value to build_email'
    );
}

done_testing();
