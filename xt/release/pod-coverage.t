#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Test::Requires {
    'Test::Pod::Coverage'  => '1.04',
    'Pod::Coverage::Moose' => '0.02',
};

my %skip = map { $_ => 1 } qw(
    Courriel::ContentType
    Courriel::Disposition
    Courriel::Helpers
    Email::Abstract::Courriel
);

my @modules
    = grep { !( $skip{$_} || /^Courriel::(?:Role|Types)/ ) } all_modules();

my %trustme = ( Courriel => ['replace_body'] );

for my $module ( sort @modules ) {
    my $trustme = [];

    if ( $trustme{$module} ) {
        if ( ref $trustme{$module} eq 'ARRAY' ) {
            my $methods = join '|', @{ $trustme{$module} };
            $trustme = [qr/^(?:$methods)$/];
        }
        else {
            $trustme = [ $trustme{$module} ];
        }
    }

    push @{$trustme}, qr/^BUILD$/;

    pod_coverage_ok(
        $module, {
            coverage_class => 'Pod::Coverage::Moose',
            trustme        => $trustme,
        },
        "Pod coverage for $module"
    );
}

done_testing();
