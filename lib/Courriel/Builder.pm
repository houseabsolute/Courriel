package Courriel::Builder;

use strict;
use warnings;

use Carp qw( croak );
use Courriel;
use Courriel::ContentType;
use Courriel::Disposition;
use Courriel::Headers;
use Courriel::Helpers qw( parse_header_with_attributes );
use Courriel::Part::Multipart;
use Courriel::Part::Single;
use DateTime;
use DateTime::Format::Mail;
use Devel::PartialDump;
use File::Basename qw( basename );
use File::LibMagic;
use File::Slurp qw( read_file );
use List::AllUtils qw( first );
use Scalar::Util qw( blessed reftype );

our @CARP_NOT = __PACKAGE__;

my @exports;

BEGIN {
    @exports = qw(
        build_email
        subject
        from
        to
        cc
        bcc
        header
        plain_body
        html_body
        attach
    );
}

use Sub::Exporter -setup => {
    exports => \@exports,
    groups  => { default => \@exports },
};

sub build_email {
    my @headers;
    my $plain_body;
    my $html_body;
    my @attachments;

    for my $p (@_) {
        _bad_value($p)
            unless reftype($p) eq 'HASH';

        if ( $p->{header} ) {
            push @headers, @{ $p->{header} };
        }
        elsif ( $p->{plain_body} ) {
            $plain_body = $p->{plain_body};
        }
        elsif ( $p->{html_body} ) {
            $html_body = $p->{html_body};
        }
        elsif ( $p->{attachment} ) {
            push @attachments, $p->{attachment};
        }
        else {
            _bad_value($p);
        }
    }

    my $body_part;
    if ( $plain_body && $html_body ) {
        my $ct = Courriel::ContentType->new(
            mime_type => 'multipart/alternative',
        );

        $body_part = Courriel::Part::Multipart->new(
            headers      => Courriel::Headers->new(),
            content_type => $ct,
            parts        => [ $plain_body, $html_body ],
        );
    }
    else {
        $body_part = first {defined} $plain_body, $html_body;

        croak "Cannot call build_email without a plain or html body"
            unless $body_part;
    }

    if (@attachments) {
        my $ct = Courriel::ContentType->new( mime_type => 'multipart/mixed' );

        $body_part = Courriel::Part::Multipart->new(
            headers      => Courriel::Headers->new(),
            content_type => $ct,
            parts        => [
                $body_part,
                @attachments,
            ],
        );
    }

    _add_needed_headers(\@headers);

    # XXX - a little incestuous but I don't really want to make this method
    # public, and delaying building the body part would make all the code more
    # complicated than it needs to be.
    $body_part->_set_headers(
        Courriel::Headers->new( headers => [@headers] ) );

    return Courriel->new( part => $body_part );
}

sub _bad_value {
    croak "A weird value was passed to build_email: "
        . Devel::PartialDump->new()->dump( $_[0] );
}

sub _add_needed_headers {
    my $headers = shift;

    my %keys = map { lc } @{$headers};

    unless ( $keys{date} ) {
        push @{$headers},
            ( Date => DateTime::Format::Mail->format_datetime( DateTime->now() ) );
    }

    unless ( $keys{'message-id'} ) {
        push @{$headers},
            ( 'Message-Id' => Email::MessageID->new()->in_brackets() );
    }

    return;
}

sub subject {
    return { header => [ Subject => shift ] };
}

sub from {
    my $from = shift;

    if ( blessed $from ) {
        $from = $from->format();
    }

    return { header => [ From => $from ] };
}

sub to {
    my @to = @_;

    @to = map { blessed($_) ? $_->format() : $_ } @to;

    return { header => [ To => join ', ', @to ] };
}

sub cc {
    my @cc = @_;

    @cc = map { blessed($_) ? $_->format() : $_ } @cc;

    return { header => [ Cc => join ', ', @cc ] };
}

sub bcc {
    my @bcc = @_;

    @bcc = map { blessed($_) ? $_->format() : $_ } @bcc;

    return { header => [ Bcc => join ', ', @bcc ] };
}

sub header {
    my $name  = shift;
    my $value = shift;

    return { header => [ $name => $value ] };
}

sub plain_body {
    my %p
        = @_ == 1
        ? ( content => shift )
        : @_;

    return {
        plain_body => _body_part(
            %p,
            mime_type => 'text/plain',
        )
    };
}

sub html_body {
    my @attachments;

    for my $i ( reverse 0 .. $#_ ) {
        if (   ref $_[$i]
            && reftype( $_[$i] ) eq 'HASH'
            && $_[$i]->{attachment} ) {

            push @attachments, splice @_, $i, 1;
        }
    }

    my %p
        = @_ == 1
        ? ( content => shift )
        : @_;

    my $body = _body_part(
        %p,
        mime_type => 'text/html',
    );

    if (@attachments) {
        $body = Courriel::Part::Multipart->new(
            headers      => Courriel::Headers->new(),
            content_type => Courriel::ContentType->new(
                mime_type => 'multipart/related'
            ),
            parts => [
                $body,
                map { $_->{attachment} } @attachments,
            ],
        );
    }

    return { html_body => $body };
}

sub _body_part {
    my %p = @_;

    $p{charset} //= 'UTF-8';

    my $ct = Courriel::ContentType->new(
        mime_type  => $p{mime_type},
        attributes => { charset => $p{charset} },
    );

    my $body = Courriel::Part::Single->new(
        headers      => Courriel::Headers->new(),
        content_type => $ct,
        encoding     => $p{encoding} // 'base64',
        content      => ( ref $p{content} ? $p{content} : $p{content} ),
    );

    return $body;
}

sub attach {
    my %p
        = @_ == 1
        ? ( file => shift )
        : @_;

    return {
        attachment => $p{file} ? _part_for_file(%p) : _part_for_content(%p) };
}

my $flm = File::LibMagic->new();

sub _part_for_file {
    my %p = @_;

    my $ct = _content_type( $flm->checktype_filename( $p{file} ) );

    my $content = read_file( $p{file} );

    return Courriel::Part::Single->new(
        headers      => Courriel::Headers->new(),
        content_type => $ct,
        disposition  => Courriel::Disposition->new(
            disposition => 'attachment',
            attributes  => { filename => basename( $p{file} ) }
        ),
        encoding => 'base64',
        content  => \$content,
    );
}

sub _part_for_content {
    my %p = @_;

    my $content_ref = ref $p{content} ? $p{content} : \$p{content};

    my $ct = _content_type( $flm->checktype_contents( ${$content_ref} ) );

    my $disp = Courriel::Disposition->new(
        disposition => 'attachment',
        attributes =>
            { $p{filename} ? ( filename => basename( $p{filename} ) ) : () }
    );

    return Courriel::Part::Single->new(
        headers      => Courriel::Headers->new(),
        content_type => $ct,
        disposition  => $disp,
        encoding     => 'base64',
        content      => $content_ref,
    );
}

sub _content_type {
    my $type = shift;

    return Courriel::ContentType->new( mime_type => 'application/unknown' )
        unless defined $type;

    my ( $mime_type, $attr ) = parse_header_with_attributes($type);

    return Courriel::ContentType->new( mime_type => 'application/unknown' )
        unless defined $mime_type && length $mime_type;

    return Courriel::ContentType->new(
        mime_type  => $mime_type,
        attributes => $attr,
    );
}

1;
