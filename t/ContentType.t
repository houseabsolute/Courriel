use strict;
use warnings;

use Test::More 0.88;

use Courriel::Header::ContentType;

{
    my $ct = Courriel::Header::ContentType->new_from_value( value => 'text/plain' );

    is( $ct->value(), 'text/plain', 'got expected value' );
    is( $ct->mime_type(), 'text/plain', 'got expected mime_type' );
}

{
    my $ct = Courriel::Header::ContentType->new_from_value(
        name  => 'content-type',
        value => 'text/plain',
    );

    is( $ct->name(), 'content-type', 'name from parameters is used' );
    is( $ct->mime_type(), 'text/plain', 'got expected mime_type' );
}

done_testing();
