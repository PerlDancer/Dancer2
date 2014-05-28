# ABSTRACT: Role for template engines

package Dancer2::Core::Role::Template;

use Dancer2::Core::Types;
use Dancer2::FileUtils qw'path';
use Carp 'croak';

use Data::Dumper;
use Moo::Role;
with 'Dancer2::Core::Role::Engine';

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

has name => (
    is      => 'ro',
    lazy    => 1,
    builder => 1,
);

sub _build_name {
    ( my $name = ref shift ) =~ s/^Dancer2::Template:://;
    $name;
}

has charset => (
    is      => 'ro',
    isa     => Str,
    default => sub {'UTF-8'},
);

has default_tmpl_ext => (
    is      => 'ro',
    isa     => Str,
    default => sub { shift->config->{extension} || 'tt' },
);

has views => (
    is  => 'rw',
    isa => Maybe [Str],
);

has layout => (
    is  => 'rw',
    isa => Maybe [Str],
);

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

sub view_pathname {
    my ( $self, $view ) = @_;

    $view = $self->_template_name($view);
    return path( $self->views, $view );
}

sub layout_pathname {
    my ( $self, $layout ) = @_;
    $layout = $self->_template_name($layout);
    return path( $self->views, 'layouts', $layout );
}

sub render_layout {
    my ( $self, $layout, $tokens, $content ) = @_;

    $layout = $self->layout_pathname($layout);

    # FIXME: not sure if I can "just call render"
    $self->render( $layout, { %$tokens, content => $content } );
}

sub apply_renderer {
    my ( $self, $request, $view, $tokens ) = @_;
    $view = $self->view_pathname($view) if !ref $view;
    $tokens = $self->_prepare_tokens_options($request,$tokens);

    $self->execute_hook( 'engine.template.before_render', $tokens );

    my $content = $self->render( $view, $tokens );
    $self->execute_hook( 'engine.template.after_render', \$content );

    # make sure to avoid ( undef ) in list context return
    defined $content and return $content;
    return;
}

sub apply_layout {
    my ( $self, $request, $content, $tokens, $options ) = @_;

    $tokens = $self->_prepare_tokens_options( $request, $tokens );

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
    my ( $self, $request, $tokens ) = @_;

    # these are the default tokens provided for template processing
    $tokens ||= {};
    $tokens->{perl_version}   = $];
    $tokens->{dancer_version} = Dancer2->VERSION;

    if ( defined $self->context ) {
        $tokens->{settings} = $self->context->app->config;
        $tokens->{request}  = $request;
        $tokens->{params}   = $request->params;
        $tokens->{vars}     = $self->context->buffer;

        $tokens->{session} = $self->context->session->data
          if $self->context->has_session;
    }

    return $tokens;
}

sub process {
    my ( $self, $request, $view, $tokens, $options ) = @_;
    my ( $content, $full_content );

    # it's important that $tokens is not undef, so that things added to it via
    # a before_template in apply_renderer survive to the apply_layout. GH#354
    $tokens  ||= {};
    $options ||= {};

    ## FIXME - Look into PR 654 so we fix the problem here as well!

    $content =
        $view
      ? $self->apply_renderer( $request, $view, $tokens )
      : delete $options->{content};

    defined $content
      and $full_content = $self->apply_layout( $request, $content, $tokens, $options );

    defined $full_content
      and return $full_content;

    croak "Template did not produce any content";
}

1;

__END__

=head1 DESCRIPTION

Any class that consumes this role will be able to be used as a template engine
under Dancer2.

In order to implement this role, the consumer B<must> implement the method C<render>. This method will receive three arguments:

=over 4

=item $self

=item $template

=item $tokens

=back

=head1 METHODS

=attr name

The name of the template engine (e.g.: Simple).

=attr charset

The charset.  The default value is B<UTF-8>.

=attr default_tmpl_ext

The default file extension.  If not provided, B<tt> is used.

=attr views

Path to the directory containing the views.

=attr layout

Path to the directory containing the layouts.

=attr engine

Contains the engine.

=method view_pathname($view)

Returns the full path to the requested view.

=method layout_pathname($layout)

Returns the full path to the requested layout.

=method render_layout($layout, \%tokens, \$content)

Render the layout with the applied tokens

=method apply_renderer($view, \%tokens)

=method apply_layout($content, \%tokens, \%options)

=method process($view, \%tokens, \%options)
