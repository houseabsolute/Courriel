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
}

done_testing();
