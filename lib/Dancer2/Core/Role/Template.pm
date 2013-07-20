# ABSTRACT: Role for template engines

package Dancer2::Core::Role::Template;

use Dancer2::Core::Types;
use Dancer2::FileUtils qw'path';
use Carp 'croak';

use Data::Dumper;
use Moo::Role;
with 'Dancer2::Core::Role::Engine';

=head1 DESCRIPTION

This role provides methods and attributes needed for working with template.

All Dancer's templates engine should consume this role, and they B<need> to
implement a C<render> method. This method will receive three arguments:

=over 4

=item $self

=item $template

=item $tokens

=back

=cut

sub supported_hooks {
    qw/
      engine.template.before_render
      engine.template.after_render
      engine.template.before_layout_render
      engine.template.after_layout_render
      /;
}

sub _build_type {'Template'}

requires 'render';

=method name

The name of the template engine (e.g.: Simple).

=cut

has name => (
    is      => 'ro',
    lazy    => 1,
    builder => 1,
);

sub _build_name {
    ( my $name = ref shift ) =~ s/^Dancer2::Template:://;
    $name;
}


=method charset

The charset.  The default value is B<UTF-8>.

=cut

has charset => (
    is      => 'ro',
    isa     => Str,
    default => sub {'UTF-8'},
);


=method default_tmpl_ext

The default file extension.  If not provided, B<tt> is used.

=cut

has default_tmpl_ext => (
    is      => 'rw',
    isa     => Str,
    default => sub { shift->config->{extension} || 'tt' },
);

=method views

Path to the directory containing the views.

=cut

has views => (
    is  => 'rw',
    isa => Maybe [Str],
);

=method layout

Path to the directory containing the layouts.

=cut

has layout => (
    is  => 'rw',
    isa => Maybe [Str],
);

=method engine

Contains the engine.

=cut

has engine => (
    is      => 'ro',
    isa     => Object,
    lazy    => 1,
    builder => 1,
);

sub _template_name {
    my ( $self, $view ) = @_;
    my $def_tmpl_ext = $self->default_tmpl_ext();
    $view .= ".$def_tmpl_ext" if $view !~ /\.\Q$def_tmpl_ext\E$/;
    return $view;
}

=method view_pathname($view)

Returns the full path to the requested view.

=cut

sub view_pathname {
    my ( $self, $view ) = @_;

    $view = $self->_template_name($view);
    return path( $self->views, $view );
}

=method layout_pathname($layout)

Returns the full path to the requested layout.

=cut

sub layout_pathname {
    my ( $self, $layout ) = @_;
    $layout = $self->_template_name($layout);
    return path( $self->views, 'layouts', $layout );
}

=method render_layout($layout, $tokens, \$content)

Render the layout with the applied tokens

=cut

sub render_layout {
    my ( $self, $layout, $tokens, $content ) = @_;

    $layout = $self->layout_pathname($layout);

    # FIXME: not sure if I can "just call render"
    $self->render( $layout, { %$tokens, content => $content } );
}

=method apply_renderer($view, $tokens)

=cut

sub apply_renderer {
    my ( $self, $view, $tokens ) = @_;
    $view = $self->view_pathname($view) if !ref $view;
    $tokens = $self->_prepare_tokens_options($tokens);

    $self->execute_hook( 'engine.template.before_render', $tokens );

    my $content = $self->render( $view, $tokens );
    $self->execute_hook( 'engine.template.after_render', \$content );

    # make sure to avoid ( undef ) in list context return
    defined $content and return $content;
    return;
}

=method apply_layout

=cut

sub apply_layout {
    my ( $self, $content, $tokens, $options ) = @_;

    $tokens = $self->_prepare_tokens_options($tokens);

   # If 'layout' was given in the options hashref, use it if it's a true value,
   # or don't use a layout if it was false (0, or undef); if layout wasn't
   # given in the options hashref, go with whatever the current layout setting
   # is.
    my $layout =
      exists $options->{layout}
      ? ( $options->{layout} ? $options->{layout} : undef )
      : ( $self->layout || $self->context->app->config->{layout} );

    # that should only be $self->config, but the layout ain't there ???

    defined $content or return;
    defined $layout  or return $content;

    $self->execute_hook(
        'engine.template.before_layout_render',
        $tokens, \$content
    );

    my $full_content = $self->render_layout( $layout, $tokens, $content );

    $self->execute_hook( 'engine.template.after_layout_render',
        \$full_content );

    # make sure to avoid ( undef ) in list context return
    defined $full_content and return $full_content;
    return;
}

sub _prepare_tokens_options {
    my ( $self, $tokens ) = @_;

    # these are the default tokens provided for template processing
    $tokens ||= {};
    $tokens->{perl_version}   = $];
    $tokens->{dancer_version} = Dancer2->VERSION;

    if ( defined $self->context ) {
        $tokens->{settings} = $self->context->app->config;
        $tokens->{request}  = $self->context->request;
        $tokens->{params}   = $self->context->request->params;
        $tokens->{vars}     = $self->context->buffer;

        $tokens->{session} = $self->context->session->data
          if $self->context->has_session;
    }

    return $tokens;
}

=method process($view, $tokens, $options)

=cut

sub process {
    my ( $self, $view, $tokens, $options ) = @_;
    my ( $content, $full_content );

    # it's important that $tokens is not undef, so that things added to it via
    # a before_template in apply_renderer survive to the apply_layout. GH#354
    $tokens  ||= {};
    $options ||= {};

    ## FIXME - Look into PR 654 so we fix the problem here as well!

    $content =
        $view
      ? $self->apply_renderer( $view, $tokens )
      : delete $options->{content};

    defined $content
      and $full_content = $self->apply_layout( $content, $tokens, $options );

    defined $full_content
      and return $full_content;

    croak "Template did not produce any content";
}

1;
