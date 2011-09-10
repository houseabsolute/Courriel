package Courriel::Types::Internal;

use strict;
use warnings;
use namespace::autoclean;

use List::AllUtils qw( all );
use Scalar::Util qw( blessed );

use MooseX::Types -declare => [
    qw(
        Body
        EmailAddressStr
        HeaderArray
        Headers
        Part
        StringRef
        )
];
use MooseX::Types::Common::String qw( NonEmptyStr );
use MooseX::Types::Moose qw( ArrayRef HashRef ScalarRef Str );

#<<<
subtype Body,
    as role_type('Courriel::Role::Body');

subtype Headers,
    as class_type('Courriel::Headers');

subtype EmailAddressStr,
    as NonEmptyStr;

coerce EmailAddressStr,
    from class_type('Email::Address'),
    via { $_->format() };

my $_check_header_array = sub {
    return 0 unless @{$_} % 2 == 0;

    my ( @even, @odd );
    for my $i ( 0 .. $#{$_} ) {
        if ( $i % 2 ) {
            push @odd, $i;
        }
        else {
            push @even, $i;
        }
    }

    return 0 unless all { defined $_ && length $_ && !ref $_ } @{$_}[@even];
    return 0
        unless all { blessed($_) && $_->isa('Courriel::Header') } @{$_}[@odd];

    return 1;
};

subtype HeaderArray,
    as ArrayRef,
    # prototype wants an actual block, not a ref to a sub
    &where($_check_header_array),
    message { 'The array reference must contain an even number of elements' };

subtype Part,
    as role_type('Courriel::Role::Part');

subtype StringRef,
    as ScalarRef[Str];

coerce StringRef,
    from Str,
    via { my $str = $_; \$str };
#>>>
1;
