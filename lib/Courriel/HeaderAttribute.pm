package Courriel::HeaderAttribute;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::HeaderAttribute;
use Courriel::Helpers qw( quote_and_escape_attribute_value );
use Courriel::Types qw( Maybe NonEmptyStr Str );

use Moose;
use MooseX::StrictConstructor;

has name => (
    is       => 'ro',
    isa      => NonEmptyStr,
    required => 1,
);

has value => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has charset => (
    is      => 'ro',
    isa     => NonEmptyStr,
    default => 'ASCII',
);

has language => (
    is      => 'ro',
    isa     => Maybe [NonEmptyStr],
    default => undef,
);

sub as_string {
    my $self = shift;

    my $value = $self->value();
    $value =~ s/\"/\\\"/g;

    my $string = $self->name();

    # XXX - need to handle charset, language, and folding into continuations
    if ( $value =~ $Courriel::Helpers::TSPECIALS || $value =~ / / ) {
        $string .= q{="} . $value . q{"};
    }
    else {
        $string .= q{=} . $value;
    }

    return $string;
}

1;
