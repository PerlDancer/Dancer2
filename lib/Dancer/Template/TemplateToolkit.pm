# ABSTRACT: Template::Toolkit backend to Dancer

package Dancer::Template::TemplateToolkit;

use strict;
use warnings;
use Carp;
use Moo;
use Dancer::Moo::Types;
use Template;

with 'Dancer::Core::Role::Template';

has engine => (
    is => 'rw',
    isa => sub { ObjectOf('Template', @_) },
);

sub BUILD {
    my ($self) = @_;

    my $charset = $self->charset;
    my @encoding = length($charset) ? ( ENCODING => $charset ) : ();

    my $tt_config = {
        ANYCASE  => 1,
        ABSOLUTE => 1,
        @encoding,
        %{$self->config},
    };

    my $start_tag = $self->config->{start_tag};
    my $stop_tag = $self->config->{stop_tag} || $self->config->{end_tag};
    $tt_config->{START_TAG} = $start_tag 
      if defined $start_tag && $start_tag ne '[%';
    $tt_config->{END_TAG}   = $stop_tag  
      if defined $stop_tag && $stop_tag  ne '%]';

    $tt_config->{INCLUDE_PATH} ||= $self->views;

    $self->engine( Template->new(%$tt_config) );
}

sub render {
    my ($self, $template, $tokens) = @_;

    if ( ! ref $template ) {
        -f $template or croak "'$template' doesn't exist or not a regular file";
    }

    my $content = "";
    my $charset = $self->charset;
    my @options = length($charset) ? ( binmode => ":encoding($charset)" ) : ();
    $self->engine->process($template, $tokens, \$content, @options) or croak $self->engine->error;
    return $content;
}

1;

__END__

=pod

=head1 SYNOPSIS

To use this engine, you may configure L<Dancer> via C<config.yaml>:

    template:   "template_toolkit"

Or you may also change the rendering engine on a per-route basis by
setting it manually with C<set>:

    # code code code
    set template => 'template_toolkit';

=head1 SUBROUTINES/METHODS

=head2 render TEMPLATE, TOKENS

Renders the template.  The first arg is a filename for the template file
or a reference to a string that contains the template.  The second arg
is a hashref for the tokens that you wish to pass to
L<Template::Toolkit> for rendering.

=head1 BUGS

Please report any bugs or feature requests to
C<bug-dancer-template-templatetoolkit at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dancer-Template-Template-Toolkit>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dancer::Template::Tiny

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dancer-Template-TemplateToolkit>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Dancer-Template-TemplateToolkit>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Dancer-Template-TemplateToolkit>

=item * Search CPAN

L<http://search.cpan.org/dist/Dancer-Template-TemplateToolkit/>

=back

=cut
