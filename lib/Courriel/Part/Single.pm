package Courriel::Part::Single;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::Types qw( StringRef );
use Email::MIME::Encodings;
use MIME::Base64 ();
use MIME::QuotedPrint ();

use Moose;

with 'Courriel::Role::Part';

has content => (
    is       => 'ro',
    isa      => StringRef,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_content',
);

has raw_content => (
    is       => 'ro',
    isa      => StringRef,
    coerce   => 1,
    required => 1,
    init_arg => 'raw_content',
);

sub is_multipart {0}

sub _build_content_type {
    return Courriel::ContentType->new( mime_type => 'text/plain' );
}

{
    my %unencoded = map { $_ => 1 } qw( 7bit 8bit binary );

    sub _build_content {
        my $self = shift;

        my $encoding = $self->encoding();

        return $self->raw_content() if $unencoded{ lc $encoding };

        return \(
            Email::MIME::Encodings::decode(
                $encoding,
                ${ $self->raw_content() }
            )
        );
    }
}

__PACKAGE__->meta()->make_immutable();

1;
