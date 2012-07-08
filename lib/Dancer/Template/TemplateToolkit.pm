# ABSTRACT: TODO

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

