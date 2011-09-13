package Courriel::Header;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Types qw( NonEmptyStr Str );

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

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: A single header's name and value

__END__

=head1 SYNOPSIS

  my $subject = $headers->get('subject');
  print $subject->value();

=head1 DESCRIPTION

This class represents a single header, which consists of a name and value.

=head1 API

This class supports the following methods:

=head1 Courriel::Header->new( ... )

This method requires two attributes, C<name> and C<value>. Both must be
strings. The C<name> cannot be empty, but the C<value> can.

=head2 $header->name()

The header name as passed to the constructor.

=head2 $header->value()

The header value as passed to the constructor.
