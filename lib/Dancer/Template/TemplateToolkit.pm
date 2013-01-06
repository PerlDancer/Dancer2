# ABSTRACT: Template toolkit engine for Dancer

package Dancer::Template::TemplateToolkit;

use strict;
use warnings;
use Carp;
use Moo;
use Dancer::Core::Types;
use Template;

with 'Dancer::Core::Role::Template';

=head1 SYNOPSIS

To use this engine, you may configure L<Dancer> via C<config.yaml>:

    template:   "template_toolkit"

Or you may also change the rendering engine on a per-route basis by
setting it manually with C<set>:

    # code code code
    set template => 'template_toolkit';

=cut

has '+engine' => (
    isa => InstanceOf['Template'],
);

sub _build_engine {
    my $self      = shift;
    my $charset   = $self->charset;
    my %tt_config = (
        ANYCASE  => 1,
        ABSOLUTE => 1,
        length($charset) ? ( ENCODING => $charset ) : (),
        %{$self->config},
    );

    my $start_tag = $self->config->{'start_tag'};
    my $stop_tag  = $self->config->{'stop_tag'} || $self->config->{end_tag};
    $tt_config{'START_TAG'} = $start_tag
      if defined $start_tag && $start_tag ne '[%';
    $tt_config{'END_TAG'}   = $stop_tag
      if defined $stop_tag && $stop_tag  ne '%]';

    $tt_config{'INCLUDE_PATH'} ||= $self->views;

    return Template->new(%tt_config);
}

=method render TEMPLATE, TOKENS

Renders the template.  The first arg is a filename for the template file
or a reference to a string that contains the template.  The second arg
is a hashref for the tokens that you wish to pass to
L<Template::Toolkit> for rendering.

=cut

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
