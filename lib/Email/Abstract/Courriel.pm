package Email::Abstract::Courriel;

use strict;
use warnings;

use Courriel 0.08;

use parent 'Email::Abstract::Plugin';

sub target {'Courriel'}

sub construct {
    my ( $class, $rfc822 ) = @_;
    Courriel->parse( text => \$rfc822 );
}

sub get_header {
    my ( $class, $obj, $header ) = @_;
    my @values = $obj->headers()->get($header);
    return wantarray ? @values : $values[0];
}

sub get_body {
    my ( $class, $obj ) = @_;
    return $obj->top_level_part()->content();
}

sub set_header {
    my ( $class, $obj, $header, @data ) = @_;
    $obj->headers()->remove($header);
    $obj->headers()->add( $header => $_ ) for @data;
}

sub set_body {
    my ( $class, $obj, $body ) = @_;
    $obj->replace_body( text => $body );
}

sub as_string {
    my ( $class, $obj ) = @_;
    $obj->as_string();
}

1;

#ABSTRACT: Email::Abstract wrapper for Courriel

__END__

=head1 DESCRIPTION

This module wraps the Courriel mail handling library with an abstract
interface, to be used with L<Email::Abstract>.

Note that Courriel doesn't really offer any simple way to set the email's
body, so the C<set_body()> method will die if it is called.

=head1 SEE ALSO

L<Email::Abstract>, L<Courriel>.

=cut

