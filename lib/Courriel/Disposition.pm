package Courriel::Disposition;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Types qw( Bool HashRef Maybe NonEmptyStr );
use DateTime;
use DateTime::Format::Mail;

use Moose;

has disposition => (
    is       => 'ro',
    isa      => NonEmptyStr,
    required => 1,
);

has is_inline => (
    is       => 'ro',
    isa      => Bool,
    init_arg => undef,
    lazy     => 1,
    default  => sub { $_[0]->disposition() ne 'attachment' },
);

has is_attachment => (
    is       => 'ro',
    isa      => Bool,
    init_arg => undef,
    lazy     => 1,
    default  => sub { !$_[0]->is_inline() },
);

has filename => (
    is       => 'ro',
    isa      => Maybe [NonEmptyStr],
    init_arg => undef,
    lazy     => 1,
    default  => sub { $_[0]->{attributes}{filename} }
);

{
    my $parser = DateTime::Format::Mail->new( loose => 1 );
    for my $attr (qw( creation_datetime modification_datetime read_datetime )) {
        ( my $name_in_header = $attr ) =~ s/_/-/g;
        $name_in_header =~ s/datetime/date/;

        my $default = sub {
            my $val = $_[0]->attributes()->{$name_in_header};
            return unless $val;

            return $parser->parse_datetime($val);
        };

        has $attr => (
            is       => 'ro',
            isa      => Maybe ['DateTime'],
            init_arg => undef,
            lazy     => 1,
            default  => $default,
        );
    }
}

has attributes => (
    is      => 'ro',
    isa     => HashRef [NonEmptyStr],
    default => sub { {} },
);

__PACKAGE__->meta()->make_immutable();

1;
