use strict;
use warnings;

use Test::Differences;
use Test::Fatal;
use Test::More 0.88;

use Test::Requires (
    'Path::Class' => '0',
);

use Email::MIME;
use File::Slurp qw( read_file );
use Path::Class qw( dir );

use Courriel;

my $dir = dir(qw( t data stress-test));

while ( my $file = $dir->next() ) {
    next if $file->is_dir();

    my $mail = read_file( $file->stringify() );

    is(
        exception { Courriel->parse( text => $mail ) },
        undef,
        'no exception from parsing ' . $file->basename()
    )
}

done_testing();
