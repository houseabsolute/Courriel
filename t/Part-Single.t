use strict;
use warnings;

use utf8;

use Test::More 0.88;

use Courriel::ContentType;
use Courriel::Headers;
use Courriel::Part::Single;
use Email::MIME::Encodings;

my $crlf = "\x0d\x0a";

{
    my $body = <<'EOF';
Some plain text
in a body.
EOF

    $body =~ s/\n/$crlf/g;

    my $part = Courriel::Part::Single->new(
        headers      => Courriel::Headers->new(),
        content_type => Courriel::ContentType->new(
            mime_type => 'text/plain',
        ),
        encoding        => '8bit',
        encoded_content => \$body,
    );

    is(
        ${ $part->content() },
        $body,
        'content matches original body'
    );
}

{
    my $body = <<'EOF';
Some plain text
in a body.
EOF

    $body =~ s/\n/$crlf/g;

    my $encoded = Email::MIME::Encodings::encode( 'base64', $body );

    my $part = Courriel::Part::Single->new(
        headers      => Courriel::Headers->new(),
        content_type => Courriel::ContentType->new(
            mime_type => 'text/plain',
        ),
        encoding        => 'base64',
        encoded_content => \$encoded,
    );

    is(
        ${ $part->content() },
        $body,
        'content matches original body - base64 encoding on part'
    );
}

{
    my $body = <<'EOF';
Some plain text
in a body.
EOF

    $body =~ s/\n/$crlf/g;

    my $encoded = Email::MIME::Encodings::encode( 'quoted-printable', $body );

    my $part = Courriel::Part::Single->new(
        headers      => Courriel::Headers->new(),
        content_type => Courriel::ContentType->new(
            mime_type => 'text/plain',
        ),
        encoding        => 'quoted-printable',
        encoded_content => \$encoded,
    );

    is(
        ${ $part->content() },
        $body,
        'content matches original body - qp encoding on part'
    );
}

{
    my $body = <<'EOF';
Some plain text
in a body.
EOF

    $body =~ s/\n/$crlf/g;

    my $encoded = Email::MIME::Encodings::encode( 'base64', $body );

    my $part = Courriel::Part::Single->new(
        headers      => Courriel::Headers->new(),
        content_type => Courriel::ContentType->new(
            mime_type => 'text/plain',
        ),
        encoding => 'base64',
        content  => \$body,
    );

    is(
        ${ $part->encoded_content() },
        $encoded,
        'encoded_content matches encoded version of content'
    );
}

{
    my $part = Courriel::Part::Single->new(
        headers => Courriel::Headers->new(),
        content_type =>
            Courriel::ContentType->new( mime_type => 'image/jpeg' ),
        disposition => Courriel::Disposition->new(
            disposition => 'attachment',
            attributes  => { filename => 'foo.jpg' },
        ),
        encoded_content => 'foo',
    );

    my $new_h = Courriel::Headers->new();

    $part->_set_headers($new_h);

    is_deeply(
        [ $new_h->headers() ],
        [
            'Content-Type'        => 'image/jpeg',
            'Content-Disposition' => q{attachment; filename="foo.jpg"},
        ],
        'content type is updated when headers are set'
    );
}

done_testing();

