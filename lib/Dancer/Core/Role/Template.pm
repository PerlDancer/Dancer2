package Dancer::Core::Role::Template;
use Dancer::Moo::Types;
use Dancer::FileUtils qw'path';

use Moo::Role;
with 'Dancer::Core::Role::Engine';
with 'Dancer::Core::Role::Hookable';

sub supported_hooks {
    qw/before_template_render after_template_render before_layout_render after_layout_render/
}

sub BUILD {
    my ($self) = @_;
    $self->install_hooks($self->supported_hooks);
}

sub type { 'Template' }

requires 'render';

has default_tmpl_ext => (
    is => 'rw',
    isa => sub { Str(@_) },
    default => 'tt',
);
has views => (
    is => 'rw',
    isa => sub { Str(@_) },
    default => '/views',
);
has layout => (
    is => 'rw',
    isa => sub { Str(@_) },
    default => 'main',
);


sub _template_name {
    my ($self, $view) = @_;
    my $def_tmpl_ext = $self->default_tmpl_ext();
    $view .= ".$def_tmpl_ext" if $view !~ /\.\Q$def_tmpl_ext\E$/;
    return $view;
}

sub view {
    my ($self, $view) = @_;

    $view = $self->_template_name($view);
    return path($self->views, $view);
}

sub render_layout {
    my ($self, $layout, $tokens, $content) = @_;

    my $layout_name = $self->_template_name($layout);
    my $layout_path = path($self->views, 'layouts', $layout_name);

    # FIXME: not sure if I can "just call render"
    $self->render($layout_path, {%$tokens, content => $content});
}

sub apply_renderer {
    my ($self, $view, $tokens) = @_;

    ($tokens, undef) = _prepare_tokens_options($tokens);

    $view = $self->view($view);

    $self->execute_hooks('before_template_render', $tokens);

    my $content = $self->render($view, $tokens);

    $self->execute_hooks('after_template_render', \$content);

    # make sure to avoid ( undef ) in list context return
    defined $content and return $content;
    return;
}

sub apply_layout {
    my ($self, $content, $tokens, $options) = @_;

    ($tokens, $options) = _prepare_tokens_options($tokens, $options);

    # If 'layout' was given in the options hashref, use it if it's a true value,
    # or don't use a layout if it was false (0, or undef); if layout wasn't
    # given in the options hashref, go with whatever the current layout setting
    # is.
    my $layout =
      exists $options->{layout}
      ? ($options->{layout} ? $options->{layout} : undef)
      : $self->layout;

    defined $content or return;

    defined $layout or return $content;

    $self->execute_hooks('before_layout_render', $tokens, \$content);

    my $full_content =
      $self->render_layout($layout, $tokens, $content);

    $self->execute_hooks('after_layout_render', \$full_content);

    # make sure to avoid ( undef ) in list context return
    defined $full_content and return $full_content;
    return;
}

sub _prepare_tokens_options {
    my ($tokens, $options) = @_;

    $options ||= {};

    # these are the default tokens provided for template processing
    $tokens ||= {};
    $tokens->{perl_version}   = $];
    $tokens->{dancer_version} = $Dancer::VERSION;

    ## FIXME - Need to recheck how to get this information.
    ## $tokens->{settings}       = Dancer::Config->settings;
    ## 
    ## # If we're processing a request, also add the request object, params and
    ## # vars as tokens:
    ## if (my $request = Dancer::SharedData->request) {
    ##    $tokens->{request}        = $request;
    ##    $tokens->{params}         = $request->params;
    ##    $tokens->{vars}           = Dancer::SharedData->vars;
    ## }
    ## 
    ## Dancer::App->current->setting('session')
    ##   and $tokens->{session} = Dancer::Session->get;

    return ($tokens, $options);
}

sub template {
    my ($class, $view, $tokens, $options) = @_;
    my ($content, $full_content);

    # it's important that $tokens is not undef, so that things added to it via
    # a before_template in apply_renderer survive to the apply_layout. GH#354
    $tokens  ||= {};
    $options ||= {};

    $content = $view ? $self->apply_renderer($view, $tokens)
                     : delete $options->{content};

    defined $content and $full_content =
      $self->apply_layout($content, $tokens, $options);

    defined $full_content
      and return $full_content;

    ## FIXME - should the template return 404 error at any given time?
    ## Dancer::Error->new(
    ##     code    => 404,
    ##     message => "Page not found",
    ## )->render();
}


1;
