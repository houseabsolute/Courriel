package Courriel::Role::Part;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::ContentType;
use Courriel::Disposition;
use Courriel::Helpers qw( parse_header_with_attributes );

use Courriel::Types qw( NonEmptyStr );

use Moose::Role;

requires '_build_content_type';

has headers => (
    is       => 'ro',
    does     => 'Courriel::Headers',
    required => 1,
);

has container => (
    is       => 'rw',
    writer   => '_set_container',
    does     => 'Courriel::Role::HasParts',
    weak_ref => 1,
);

has content_type => (
    is      => 'ro',
    isa     => 'Courriel::ContentType',
    lazy    => 1,
    builder => '_build_content_type',
    handles => [qw( mime_type charset )],
);

has disposition => (
    is       => 'ro',
    isa      => 'Courriel::Disposition',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_disposition',
    handles  => [qw( is_attachment is_inline filename )],
);

has encoding => (
    is      => 'ro',
    isa     => NonEmptyStr,
    default => '8bit',
);

sub _build_disposition {
    my $self = shift;

    my @disp = $self->headers()->get('Content-Disposition');
    if ( @disp > 1 ) {
        die 'This email defines more than one Content-Disposition header.';
    }

    my ( $disposition, $attributes )
        = defined $disp[0]
        ? parse_header_with_attributes( $disp[0] )
        : ( 'inline', {} );

    return Courriel::Disposition->new(
        disposition => $disposition,
        attributes  => $attributes,
    );
}

1;
