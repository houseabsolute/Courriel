use strict;
use warnings;

use Test::Requires {
    'Email::Sender' => '0',
};

use Test::Fatal;
use Test::More 0.88;

use Courriel::Builder;

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }
use Email::Sender::Simple qw( sendmail );

{
    my $email = build_email(
        subject('test send'),
        from('joe@example.com'),
        to('jane@example.com'),
        plain_body('This is the body.'),
    );

    sendmail($email);

    my @sent = Email::Sender::Simple->default_transport()->deliveries();

    is(
        scalar @sent, 1,
        'sent one email'
    );

    is_deeply(
        $sent[0]->{envelope}, {
            from => 'joe@example.com',
            to   => ['jane@example.com'],
        },
        'got the right envelope for sent email'
    );

    is(
        $sent[0]->{email}->get_body(),
        $email->plain_body_part()->content(),
        'sent email had the right body'
    );
}

done_testing();
