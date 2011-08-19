package Courriel;

use 5.10.0;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::ContentType;
use Courriel::Headers;
use Courriel::Helpers qw( parse_header_with_attributes unique_boundary );
use Courriel::Part::Multipart;
use Courriel::Part::Single;
use Courriel::Types
    qw( ArrayRef Bool Headers Maybe NonEmptyStr Part StringRef );
use DateTime;
use DateTime::Format::Mail;
use Email::Address;
use List::AllUtils qw( uniq );
use MooseX::Params::Validate qw( validated_list );

use Moose;
use MooseX::StrictConstructor;

has top_level_part => (
    is       => 'rw',
    writer   => '_replace_top_level_part',
    isa      => Part,
    init_arg => 'part',
    required => 1,
    handles  => [
        qw(
            as_string
            content_type
            headers
            is_multipart
            )
    ]
);

has subject => (
    is       => 'ro',
    isa      => Maybe [NonEmptyStr],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_subject',
);

has datetime => (
    is       => 'ro',
    isa      => 'DateTime',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_datetime',
);

has _to => (
    traits   => ['Array'],
    isa      => ArrayRef ['Email::Address'],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_to',
    handles  => {
        to => 'elements',
    },
);

has _cc => (
    traits   => ['Array'],
    isa      => ArrayRef ['Email::Address'],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_cc',
    handles  => {
        cc => 'elements',
    },
);

has from => (
    is       => 'ro',
    isa      => Maybe ['Email::Address'],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_from',
);

has _participants => (
    traits   => ['Array'],
    isa      => ArrayRef ['Email::Address'],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_participants',
    handles  => {
        participants => 'elements',
    },
);

has _recipients => (
    traits   => ['Array'],
    isa      => ArrayRef ['Email::Address'],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_recipients',
    handles  => {
        recipients => 'elements',
    },
);

has plain_body_part => (
    is       => 'ro',
    isa      => Maybe ['Courriel::Part::Single'],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_plain_body_part',
);

has html_body_part => (
    is       => 'ro',
    isa      => Maybe ['Courriel::Part::Single'],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_html_body_part',
);

sub part_count {
    my $self = shift;

    return $self->is_multipart()
        ? $self->top_level_part()->part_count()
        : 1;
}

sub parts {
    my $self = shift;

    return $self->is_multipart()
        ? $self->top_level_part()->parts()
        : $self->top_level_part();
}

sub clone_without_attachments {
    my $self = shift;

    my $plain_body = $self->plain_body_part();
    my $html_body  = $self->html_body_part();

    my $headers = $self->headers();

    if ( $plain_body && $html_body ) {
        my $ct = Courriel::ContentType->new(
            mime_type  => 'multipart/alternative',
            attributes => { boundary => unique_boundary() },
        );

        return Courriel->new(
            part => Courriel::Part::Multipart->new(
                content_type => $ct,
                headers      => $headers,
                parts => [ $plain_body, $html_body ],
            )
        );
    }
    elsif ($plain_body) {
        return Courriel->new(
            part => Courriel::Part::Single->new(
                content_type    => $plain_body->content_type(),
                headers         => $headers,
                encoding        => $plain_body->encoding(),
                encoded_content => $plain_body->encoded_content(),
            )
        );
    }
    elsif ($html_body) {
        return Courriel->new(
            part => Courriel::Part::Single->new(
                content_type    => $html_body->content_type(),
                headers         => $headers,
                encoding        => $html_body->encoding(),
                encoded_content => $html_body->encoded_content(),
            )
        );
    }

    die "Cannot find a text or html body in this email!";
}

sub _build_subject {
    my $self = shift;

    return $self->headers()->get('Subject');
}

{
    my $parser = DateTime::Format::Mail->new( loose => 1 );

    sub _build_datetime {
        my $self = shift;

        # Stolen from Email::Date
        my $raw_date 
            = $self->headers()->get('Date')
            || $self->_find_date_received( $self->headers()->get('Received') )
            || $self->headers()->get('Resent-Date');

        if ( defined $raw_date && length $raw_date ) {
            my $dt = eval { $parser->parse_datetime($raw_date) };

            if ($dt) {
                $dt->set_time_zone('UTC');
                return $dt;
            }
        }

        return DateTime->now( time_zone => 'UTC' );
    }
}

# Stolen from Email::Date
sub _find_date_received {
    shift;

    return unless defined $_[0] and length $_[0];

    my $most_recent = pop;

    $most_recent =~ s/.+;//;

    return $most_recent;
}

sub _build_to {
    my $self = shift;

    my @addresses
        = map { Email::Address->parse($_) } $self->headers()->get('To');

    return $self->_unique_addresses( \@addresses );
}

sub _build_cc {
    my $self = shift;

    my @addresses
        = map { Email::Address->parse($_) } $self->headers()->get('CC');

    return $self->_unique_addresses( \@addresses );
}

sub _build_from {
    my $self = shift;

    my @addresses = Email::Address->parse( $self->headers()->get('From') );

    return $addresses[0];
}

sub _build_recipients {
    my $self = shift;

    my @addresses = ( $self->to(), $self->cc() );

    return $self->_unique_addresses( \@addresses );
}

sub _build_participants {
    my $self = shift;

    my @addresses
        = grep {defined} ( $self->from(), $self->to(), $self->cc() );

    return $self->_unique_addresses( \@addresses );
}

sub _unique_addresses {
    my $self      = shift;
    my $addresses = shift;

    my %seen;
    return [ grep { !$seen{ $_->original() }++ } @{$addresses} ];
}

sub _build_plain_body_part {
    my $self = shift;

    return $self->first_part_matching(
        sub {
            $_[0]->mime_type() eq 'text/plain'
                && $_[0]->is_inline();
        }
    );
}

sub _build_html_body_part {
    my $self = shift;

    return $self->first_part_matching(
        sub {
            $_[0]->mime_type() eq 'text/html'
                && $_[0]->is_inline();
        }
    );
}

sub first_part_matching {
    my $self  = shift;
    my $match = shift;

    my @parts = $self->top_level_part();

    for ( my $part = shift @parts; $part; $part = shift @parts ) {
        return $part if $match->($part);

        push @parts, $part->parts() if $part->is_multipart();
    }
}

sub all_parts_matching {
    my $self  = shift;
    my $match = shift;

    my @parts = $self->top_level_part();

    my @match;
    for ( my $part = shift @parts; $part; $part = shift @parts ) {
        push @match, $part if $match->($part);

        push @parts, $part->parts() if $part->is_multipart();
    }

    return @match;
}

{
    my @spec = ( text => { isa => StringRef, coerce => 1 } );

    # This is needed for Email::Abstract compatibility but it's a godawful
    # idea, and even Email::Abstract says not to do this.
    #
    # It's much safer to just make a new Courriel object from scratch.
    sub replace_body {
        my $self = shift;
        my ($text) = validated_list(
            \@_,
            @spec,
        );

        my $part = Courriel::Part::Single->new(
            headers         => $self->headers(),
            encoded_content => $text,
        );

        $self->_replace_top_level_part($part);

        return;
    }
}

{
    my @spec = ( text => { isa => StringRef, coerce => 1 } );

    sub parse {
        my $class = shift;
        my ($text) = validated_list(
            \@_,
            @spec,
        );

        return $class->new( part => $class->_parse($text) );
    }
}

sub _parse {
    my $class = shift;
    my $text  = shift;

    my ( $line_sep, $sep_idx, $headers ) = $class->_parse_headers($text);

    substr( ${$text}, 0, $sep_idx ) = q{};

    return $class->_parse_parts( $text, $headers );
}

sub _parse_headers {
    my $class = shift;
    my $text  = shift;

    my $header_text;
    my $sep_idx;
    my $line_sep;

    # We want to ignore mbox message separators - this is a pretty lax parser,
    # but we may find broken lines. The key is that it starts with From
    # followed by space, not a colon.
    ${$text} =~ s/^From\s+.+$Courriel::Helpers::LINE_SEP_RE//;
    # Some broken emails may split the From line in an arbitrary spot
    ${$text} =~ s/^[^:]+$Courriel::Helpers::LINE_SEP_RE//g;

    if ( ${$text} =~ /(.+?)($Courriel::Helpers::LINE_SEP_RE)\2/s ) {
        $header_text = $1 . $2;
        $sep_idx     = ( length $header_text ) + ( length $2 );
        $line_sep    = $2;
    }
    else {
        return ( q{}, 0, Courriel::Headers::->new() );
    }

    # Need to quote class name or else this perl sees this as
    # Courriel::Headers() because of the Headers type constraint.
    my $headers = Courriel::Headers::->parse(
        text     => \$header_text,
        line_sep => $line_sep,
    );

    return ( $line_sep, $sep_idx, $headers );
}

sub _parse_parts {
    my $class   = shift;
    my $text    = shift;
    my $headers = shift;

    my ( $mime, $ct_attr ) = $class->_content_type_from_headers($headers);

    if ( $mime !~ /^multipart/ ) {
        return Courriel::Part::Single->new(
            headers         => $headers,
            encoded_content => $text,
        );
    }

    my $boundary = $ct_attr->{boundary}
        // die q{The message's mime type claims this is a multipart message (}
        . $mime
        . q{) but it does not specify a boundary.};

    my ( $preamble, $all_parts, $epilogue ) = ${$text} =~ /
                (.*?)                   # preamble
                ^--\Q$boundary\E\s*
                (.+)                    # all parts
                ^--\Q$boundary\E--\s*
                (.*)                    # epilogue
                /smx;

    my @part_text;

    if ( defined $all_parts ) {
        @part_text = split /^--\Q$boundary\E\s*/m, $all_parts;
    }

    unless (@part_text) {
        ${$text} =~ s/^--\Q$boundary\E\s*//m;
        push @part_text, ${$text};
    }

    return Courriel::Part::Multipart->new(
        headers => $headers,
        (
                   defined $preamble
                && length $preamble
                && $preamble =~ /\S/ ? ( preamble => $preamble ) : ()
        ),
        (
                   defined $epilogue
                && length $epilogue
                && $epilogue =~ /\S/ ? ( epilogue => $epilogue ) : ()
        ),
        boundary => $boundary,
        parts => [ map { $class->_parse( \$_ ) } @part_text ],
    );
}

sub _content_type_from_headers {
    my $class   = shift;
    my $headers = shift;

    my @ct = $headers->get('Content-Type');
    if ( @ct > 1 ) {
        die 'This email defines more than one Content-Type header.';
    }

    return defined $ct[0]
        ? parse_header_with_attributes( $ct[0] )
        : ( 'text/plain', {} );
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: High level email parsing and manipulation

__END__

=head1 SYNOPSIS

    my $email = Courriel->parse( text => $raw_email );

    print $email->subject();

    print $_->address() for $email->participants();

    print $email->datetime()->year();

    if ( my $part = $email->plain_body_part() ) {
        print $part->content();
    }

=head1 DESCRIPTION

B<This software is still very alpha, and the API may change without warning in
future versions.>

This class exists to provide a high level API for working with emails,
particular for processing incoming email. It is primarily a wrapper around the
other classes in the Courriel distro, especially L<Courriel::Headers>,
L<Courriel::Part::Single>, and L<Courriel::Part::Multipart>. If you need lower
level information about an email, it should be available from one of this
classes.

=head1 API

This class provides the following methods:

=head2 Courriel->parse( text => $raw_email )

This parses the given text and returns a new Courriel object. The text can be
provided as a string or a reference to a string.

If you pass a reference, then the scalar underlying the reference I<will> be
modified, so don't pass in something you don't want modified.

=head2 $email->parts()

Returns an array (not a reference) of the parts this email contains.

=head2 $email->part_count()

Returns the number of parts this email contains.

=head2 $email->is_multipart()

Returns true if the top-level part is a multipart part, false otherwise.

=head2 $email->top_level_part()

Returns the actual top level part for the object. You're probably better off
just calling C<< $email->parts() >> most of the time, since when the email is
multipart, the top level part is just a container.

=head2 $email->subject()

Returns the email's Subject header value, or C<undef> if it doesn't have one.

=head2 $email->datetime()

Returns a L<DateTime> object for the email. The DateTime object is always in
the "UTC" time zone.

This uses the Date header by default one. Otherwise it looks at the date in
the first Received header, and then it looks for a Resent-Date header. If none
of these exists, it just returns C<< DateTime->now() >>.

=head2 $email->from()

This returns a single L<Email::Address> object based on the From header of the
email. If the email has no From header, it returns C<undef>.

=head2 $email->participants()

This returns a list of L<Email::Address> objects, one for each unique
participant in the email. This includes any address in the From, To, or CC
headers.

=head2 $email->recipients()

This returns a list of L<Email::Address> objects, one for each unique
recipient in the email. This includes any address in the To or CC headers.

=head2 $email->to()

This returns a list of L<Email::Address> objects, one for each unique
address in the To header.

=head2 $email->cc()

This returns a list of L<Email::Address> objects, one for each unique
address in the CC header.

=head2 $email->plain_body_part()

This returns the first L<Courriel::Part::Single> object in the email with a
mime type of "text/plain" and an inline disposition, if one exists.

=head2 $email->html_body_part()

This returns the first L<Courriel::Part::Single> object in the email with a
mime type of "text/html" and an inline disposition, if one exists.

=head2 $email->clone_without_attachments()

Returns a new Courriel object that only contains inline parts from the
original email, effectively removing all attachments.

=head2 $email->first_part_matching( sub { ... } )

Given a subroutine reference, this method calls that subroutine for each part
in the email, in a depth-first search.

The subroutine receives the part as its only argument. If it returns true,
this method returns that part.

=head2 $email->all_parts_matching( sub { ... } )

Given a subroutine reference, this method calls that subroutine for each part
in the email, in a depth-first search.

The subroutine receives the part as its only argument. If it returns true,
this method includes that part.

This method returns all of the parts that match the subroutine.

=head2 $email->content_type()

Returns the L<Courriel::ContentType> object associated with the email.

=head2 $email->headers()

Returns the L<Courriel::Headers> object for this email.

=head2 $part->as_string()

Returns the email as a string, along with its headers. Lines will be
terminated with "\r\n".

=head1 FUTURE PLANS

This release is still rough, and I have some plans for additional features:

=head2 More methods for walking all parts

Some more methods for walking/collecting multiple parts would be useful.

=head2 More?

Stay tuned for details.

=head1 WHY DID I WRITE THIS MODULE?

There a lot of email modules/distros on CPAN. Why didn't I use/fix one of them?

=over 4

=item * L<Mail::Box>

This one probably does everything this module does and more, but it's really,
really big and complicated, forcing the end user to make a lot of choices just
to get started. If you need it, it's great, but I generally find it to be too
much module for me.

=item * L<Email::Simple> and L<Email::MIME>

These are surprisingly B<not> simple. They suffer from a problematic API (too
high level in some spots, too low in others), and a poor separation of
concerns. I've hacked on these enough to know that I can never make them do
what I want.

=item * Everything Else

There's a lot of other email modules on CPAN, but none of them really seem any
better than the ones mentioned above.

=back

=head1 CREDITS

This module rips some chunks of code from a few other places, notably several
of the Email suite modules.
