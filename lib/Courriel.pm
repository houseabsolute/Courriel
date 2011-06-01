package Courriel;

use 5.10.0;

use strict;
use warnings;
use namespace::autoclean;

use Courriel::ContentType;
use Courriel::Headers;
use Courriel::Helpers qw( parse_header_with_attributes );
use Courriel::Part::Multipart;
use Courriel::Part::Single;
use Courriel::Types qw( ArrayRef Bool Headers Maybe NonEmptyStr Part StringRef );
use DateTime;
use DateTime::Format::Mail;
use Email::Address;
use List::AllUtils qw( uniq );
use MooseX::Params::Validate qw( validated_list );

use Moose;

has _part => (
    is       => 'ro',
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
    isa      => Maybe[NonEmptyStr],
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
    isa      => Maybe['Courriel::Part::Single'],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_plain_body_part',
);

has html_body_part => (
    is       => 'ro',
    isa      => Maybe['Courriel::Part::Single'],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_html_body_part',
);

sub part_count {
    my $self = shift;

    return $self->is_multipart()
        ? $self->_part()->part_count()
        : 1;
}

sub parts {
    my $self = shift;

    return $self->is_multipart()
        ? $self->_part()->parts()
        : $self->_part();
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

sub _build_recipients {
    my $self = shift;

    my @addresses = map { Email::Address->parse($_) }
        map { $self->headers()->get($_) } qw( To CC );

    my %seen;
    return [ grep { !$seen{ $_->original() }++ } @addresses ];
}

sub _build_participants {
    my $self = shift;

    my @addresses = map { Email::Address->parse($_) }
        map { $self->headers()->get($_) } qw( From To CC );

    my %seen;
    return [ grep { !$seen{ $_->original() }++ } @addresses ];
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
    my $self = shift;
    my $match = shift;

    my @parts = $self->_part();

    for ( my $part = shift @parts; $part; $part = shift @parts ) {
        return $part if $match->($part);

        push @parts, $part->parts() if $part->is_multipart();
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

    # We want to ignore mbox message separators
    ${$text} =~ s/^From .+ \d\d:\d\d:\d\d \d\d\d\d$Courriel::Helpers::LINE_SEP_RE//;

    if ( ${$text} =~ /(.+?)($Courriel::Helpers::LINE_SEP_RE)\2/s ) {
        $header_text = $1 . $2;
        $sep_idx     = ( length $header_text ) + ( length $2 );
        $line_sep    = $2;
    }
    else {
        die
            'The text you passed to parse() does not appear to be a valid email.';
    }

    # Need to quote class name or else this perl sees this as
    # Courriel::Headers() because of the Headers type constraint.
    my $headers = 'Courriel::Headers'->parse(
        text     => \$header_text,
        line_sep => $line_sep,
    );

    return ( $line_sep, $sep_idx, $headers );
}

sub _parse_parts {
    my $class   = shift;
    my $text    = shift;
    my $headers = shift;

    my $ct = $class->_content_type_from_headers($headers);

    if ( $ct->mime_type() !~ /^multipart/ ) {
        return Courriel::Part::Single->new(
            content_type => $ct,
            headers      => $headers,
            raw_content  => $text,
        );
    }

    my $boundary = $ct->attribute('boundary')
        // die q{The message's mime type claims this is a multipart message (}
        . $ct->mime_type()
        . q{) but it does not specify a boundary.};

    my ( $preamble, $all_parts, $epilogue ) = ${$text} =~ /
                (.*?)                   # preamble
                ^--\Q$boundary\E\s*
                (.+)                    # all parts
                ^--\Q$boundary\E--\s*
                (.*)                    # epilogue
                /smx;

    my @part_text = split /^--\Q$boundary\E\s*/m, $all_parts;

    die 'Could not parse any parts from a supposedly multipart message.'
        unless @part_text;

    return Courriel::Part::Multipart->new(
        content_type => $ct,
        headers      => $headers,
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
        parts    => [ map { $class->_parse( \$_ ) } @part_text ],
    );
}

sub _content_type_from_headers {
    my $class   = shift;
    my $headers = shift;

    my @ct = $headers->get('Content-Type');
    if ( @ct > 1 ) {
        die 'This email defines more than one Content-Type header.';
    }

    my ( $mime_type, $attributes )
        = defined $ct[0]
        ? parse_header_with_attributes( $ct[0] )
        : ( 'text/plain', {} );

    return Courriel::ContentType->new(
        mime_type  => $mime_type,
        attributes => $attributes,
    );
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: High level email parsing and manipulation

__END__

=head1 SYNOPSIS

    my $email = Courriel->parse( text => \$text );

    print $email->subject();

    print $_->address() for $email->participants();

    print $email->datetime()->year();

    if ( my $part = $email->text_body_part() ) {
        print ${ $part->content() };
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

=head2 Courriel->parse( text => \$text )

This parses the given text and returns a new Courriel object. The text can be
provided as a string or a reference to a string. The scalar underlying the
reference I<will> be modified, so don't pass in something you don't want
modified.

=head2 $email->parts()

Returns an array (not a reference) of the parts this email contains.

=head2 $email->part_count()

Returns the number of parts this email contains.

=head2 $email->is_multipart()

Returns true if the top-level part is a multipart part, false otherwise.

=head2 $email->subject()

Returns the email's Subject header value, or C<undef> if it doesn't have one.

=head2 $email->datetime()

Returns a L<DateTime> object for the email. The DateTime object is always in
the "UTC" time zone.

This uses the Date header by default one. Otherwise it looks at the date in
the first Received header, and then it looks for a Resent-Date header. If none
of these exists, it just returns C<< DateTime->now() >>.

=head2 $email->participants()

This returns a list of L<Email::Address> objects, one for each unique
participant in the email. This includes any address in the From, To, or CC
headers.

=head2 $email->recipients()

This returns a list of L<Email::Address> objects, one for each unique
recipient in the email. This includes any address in the To or CC headers.

=head2 $email->plain_body_part()

This returns the first L<Courriel::Part::Single> object in the email with a
mime type of "text/plain" and an inline disposition, if one exists.

=head2 $email->html_body_part()

This returns the first L<Courriel::Part::Single> object in the email with a
mime type of "text/html" and an inline disposition, if one exists.

=head2 $email->first_part_matching( sub { ... } )

Given a subroutine reference, this method calls that subroutine for each part
in the email, in a depth-first search.

The subroutine receives the part as its only argument. If it returns true,
this method returns that part.

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

=head2 Attachment Stripping

I plan to add an C<< $email->strip_attachments() >> method that actually works
properly, unlike L<Email::MIME::Attachment::Stripper>. This method will leave
behind I<all> inline parts, including their containers (if they're in a
"multipart/alternative" part, for example).

=head2 Email Building

As of this release, the distro does not yet include any high-level method for
building complicated emails from code. I plan to write some sort of sugar
layer like:

    build_email(
        subject('Foo'),
        to( 'foo@example.com', 'bar@example.com' ),
        from('joe@example.com'),
        text_body(...),
        html_body(...),
        attach('path/to/image.jpg'),
        attach('path/to/spreadsheet.xls'),
    );

=head2 More?

Stay tuned for details.

=head1 WHY DID I WRITE THIS MODULE?

There a lot of email modules/distros on CPAN. Why didn't I use/fix one of them?

=over 4

=item * L<Mail::Box>

This one probably does everything this module does and more, but it's really,
really big and complicated. If you need it, it's great, but I generally find
it to be too much module for me.

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
