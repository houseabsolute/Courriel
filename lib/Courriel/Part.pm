package Courriel::Part;

use strict;
use warnings;
use namespace::autoclean;

sub new_from_content_type {
    my $self = shift;
    my %p = @_;

    my $ct = $p{content_type} // q{};

    if ( $ct =~ /^multipart/ ) {
        return Courriel::Part::Multipart->new(%p);
    }
    else {
        return Courriel::Part::Single->new(%p);
    }
}

1;
