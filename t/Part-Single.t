use strict;
use warnings;

use utf8;

use Test::More 0.88;

use Courriel::ContentType;
use Courriel::Headers;
use Courriel::Part::Single;
use Email::MIME::Encodings;
use Encode qw( encode );
use MIME::Base64 qw( encode_base64 );

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
        $part->content(),
        $body,
        'content matches original body'
    );

    is(
        ${ $part->content_ref() },
        $body,
        'content_ref matches original body'
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
        $part->content(),
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
        $part->content(),
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

    is_deeply(
        [ $part->headers()->get('Content-Transfer-Encoding') ],
        ['base64'],
        'Content-Transfer-Encoding is always set in part headers'
    );

    is(
        $part->encoded_content(),
        $encoded,
        'encoded_content matches encoded version of content'
    );

    is(
        ${ $part->encoded_content_ref() },
        $encoded,
        'encoded_content_ref matches encoded version of content'
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
            'Content-Type'              => 'image/jpeg',
            'Content-Disposition'       => q{attachment; filename="foo.jpg"},
            'Content-Transfer-Encoding' => '8bit',
        ],
        'content type is updated when headers are set'
    );
}

{
    my $orig_content = "foo \x{4E00} bar";
    my $encoded = encode_base64( encode( 'UTF-8', $orig_content ) );

    my $part = Courriel::Part::Single->new(
        headers      => Courriel::Headers->new(),
        content_type => Courriel::ContentType->new(
            mime_type  => 'text/plain',
            attributes => { charset => 'UTF-8' },
        ),
        encoding        => 'base64',
        encoded_content => $encoded,
    );

    is(
        $part->content(),
        $orig_content,
        'decoded content matches original content',
    );
}

{
    my $orig_content = "foo \x{4E00} bar";

    my $part = Courriel::Part::Single->new(
        headers      => Courriel::Headers->new(),
        content_type => Courriel::ContentType->new(
            mime_type  => 'text/plain',
            attributes => { charset => 'UTF-8' },
        ),
        encoding => 'base64',
        content  => $orig_content,
    );

    is(
        $part->encoded_content(),
        encode_base64(
            encode( 'UTF-8', $orig_content ), $Courriel::Helpers::CRLF
        ),
        'encoded content matches expected when original contains UTF-8',
    );
}

done_testing();

