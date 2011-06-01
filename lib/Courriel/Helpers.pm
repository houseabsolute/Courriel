package Courriel::Helpers;

use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( fold_header parse_header_with_attributes );

our $CRLF = "\x0d\x0a";

# from Email::Simple
our $LINE_SEP_RE = qr/(?:\x0a\x0d|\x0d\x0a|\x0a|\x0d)/;

sub fold_header {
    my $line = shift;

    my $folded = q{};

    # Algorithm stolen from Email::Simple::Header
    while ($line) {
        if ($line =~ s/^(.{0,76})(\s|\z)//) {
            $folded .= $1 . $CRLF;
            $folded .= q{  } if $line;
        } else {
            # Basically nothing we can do. :(
            $folded .= $line . $CRLF;
            last;
        }
    }

    return $folded;
}

sub parse_header_with_attributes {
    my $text = shift;

    my ($val) = $text =~ /(.+?)(s*;.+|\z)/;

    return (
        $val,
        _parse_attributes($2) // {},
    );
}

# The rest of the code was taken mostly wholesale from Email::MIME::ContentType.
my $tspecials = quotemeta '()<>@,;:\\"/[]?=';
my $extract_quoted
    = qr/(?:\"(?:[^\\\"]*(?:\\.[^\\\"]*)*)\"|\'(?:[^\\\']*(?:\\.[^\\\']*)*)\')/;

sub _parse_attributes {
    local $_ = shift;
    my $attribs = {};
    while ($_) {
        s/^;//;
        s/^\s+// and next;
        s/\s+$//;
        unless (s/^([^$tspecials]+)=//) {

            # We check for $_'s truth because some mail software generates a
            # Content-Type like this: "Content-Type: text/plain;"
            # RFC 1521 section 3 says a parameter must exist if there is a
            # semicolon.
            die "Illegal header parameter $_" if $_;
            return $attribs;
        }
        my $attribute = lc $1;
        my $value     = _extract_ct_attribute_value();
        $value =~ s/\\([\\"])/$1/g;
        $attribs->{$attribute} = $value;
    }
    return $attribs;
}

sub _extract_ct_attribute_value {    # EXPECTS AND MODIFIES $_
    my $value;
    while ($_) {
        s/^([^$tspecials]+)// and $value .= $1;
        s/^($extract_quoted)// and do {
            my $sub = $1;
            $sub =~ s/^["']//;
            $sub =~ s/["']$//;
            $value .= $sub;
        };
        /^;/ and last;
        /^([$tspecials])/ and do {
            die "Unquoted $1 not allowed in header attribute!";
            return;
            }
    }
    return $value;
}

1;
