# ABSTRACT: Role for template engines

package Dancer2::Core::Role::Template;

use Dancer2::Core::Types;
use Dancer2::FileUtils 'path';
use Carp 'croak';
use Ref::Util qw< is_ref >;

use Moo::Role;
with 'Dancer2::Core::Role::Engine';

sub hook_aliases {
    {
        before_template_render => 'engine.template.before_render',
        after_template_render  => 'engine.template.after_render',
        before_layout_render   => 'engine.template.before_layout_render',
        after_layout_render    => 'engine.template.after_layout_render',
    }
}

sub supported_hooks { values %{ shift->hook_aliases } }

sub _build_type {'Template'}

requires 'render';

has log_cb => (
    is      => 'ro',
    isa     => CodeRef,
    default => sub { sub {1} },
);

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

has engine => (
    is      => 'ro',
    isa     => Object,
    lazy    => 1,
    builder => 1,
);

has settings => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    default => sub { +{} },
    writer  => 'set_settings',
);

# The attributes views, layout and layout_dir have triggers in
# Dancer2::Core::App that enable their values to be modified by
# the `set` keyword. As such, these are defined as read-write attrs.

has views => (
    is  => 'rw',
    isa => Maybe [Str],
);

has layout => (
    is  => 'rw',
    isa => Maybe [Str],
);

has layout_dir => (
    is  => 'rw',
    isa => Maybe [Str],
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

    return path(
        $self->views,
        $self->layout_dir,
        $self->_template_name($layout),
    );
}

sub pathname_exists {
    my ( $self, $pathname ) = @_;
    return -f $pathname;
}

sub render_layout {
    my ( $self, $layout, $tokens, $content ) = @_;

    $layout = $self->layout_pathname($layout);

    # FIXME: not sure if I can "just call render"
    $self->render( $layout, { %$tokens, content => $content } );
}

sub apply_renderer {
    my ( $self, $view, $tokens ) = @_;
    $view = $self->view_pathname($view) if !is_ref($view);
    $tokens = $self->_prepare_tokens_options( $tokens );

    $self->execute_hook( 'engine.template.before_render', $tokens );

    my $content = $self->render( $view, $tokens );
    $self->execute_hook( 'engine.template.after_render', \$content );

    # make sure to avoid ( undef ) in list context return
    defined $content and return $content;
    return;
}

sub apply_layout {
    my ( $self, $content, $tokens, $options ) = @_;

    $tokens = $self->_prepare_tokens_options( $tokens );

   # If 'layout' was given in the options hashref, use it if it's a true value,
   # or don't use a layout if it was false (0, or undef); if layout wasn't
   # given in the options hashref, go with whatever the current layout setting
   # is.
    my $layout =
      exists $options->{layout}
      ? ( $options->{layout} ? $options->{layout} : undef )
      : ( $self->layout || $self->config->{layout} );

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
    $tokens->{perl_version}   = $^V;
    $tokens->{dancer_version} = Dancer2->VERSION;
    $tokens->{settings}       = $self->settings;

    # no request when template is called as a global keyword
    if ( $self->has_request ) {
        $tokens->{request}  = $self->request;
        $tokens->{params}   = $self->request->params;
        $tokens->{vars}     = $self->request->vars;

        # a session can not exist if there is no request
        $tokens->{session} = $self->session->data
          if $self->has_session;
    }

    return $tokens;
}

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

Any template receives the following tokens, by default:

=over 4

=item * C<perl_version>

Current version of perl, effectively C<$^V>.

=item * C<dancer_version>

Current version of Dancer2, effectively C<< Dancer2->VERSION >>.

=item * C<settings>

A hash of the application configuration.

=item * C<request>

The current request object.

=item * C<params>

A hash reference of all the parameters.

Currently the equivalent of C<< $request->params >>.

=item * C<vars>

The list of request variables, which is what you would get if you
called the C<vars> keyword.

=item * C<session>

The current session data, if a session exists.

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

=attr layout_dir

Relative path to the layout directory.

Default: B<layouts>.

=attr engine

Contains the engine.

=method view_pathname($view)

Returns the full path to the requested view.

=method layout_pathname($layout)

Returns the full path to the requested layout.

=method pathname_exists($pathname)

Returns true if the requested pathname exists. Can be used for either views
or layouts:

    $self->pathname_exists( $self->view_pathname( 'some_view' ) );
    $self->pathname_exists( $self->layout_pathname( 'some_layout' ) );

=method render_layout($layout, \%tokens, \$content)

Render the layout with the applied tokens

=method apply_renderer($view, \%tokens)

=method apply_layout($content, \%tokens, \%options)

=method process($view, \%tokens, \%options)
