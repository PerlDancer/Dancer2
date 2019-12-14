# ABSTRACT: Template toolkit engine for Dancer2

package Dancer2::Template::TemplateToolkit;

use Moo;
use Carp qw<croak>;
use Dancer2::Core::Types;
use Dancer2::FileUtils qw<path>;
use Scalar::Util ();
use Template;

with 'Dancer2::Core::Role::Template';

has '+engine' => ( isa => InstanceOf ['Template'], );

sub _build_engine {
    my $self      = shift;
    my $charset   = $self->charset;
    my %tt_config = (
        ANYCASE  => 1,
        ABSOLUTE => 1,
        length($charset) ? ( ENCODING => $charset ) : (),
        %{ $self->config },
    );

    my $start_tag = $self->config->{'start_tag'};
    my $stop_tag = $self->config->{'stop_tag'} || $self->config->{end_tag};
    $tt_config{'START_TAG'} = $start_tag
      if defined $start_tag && $start_tag ne '[%';
    $tt_config{'END_TAG'} = $stop_tag
      if defined $stop_tag && $stop_tag ne '%]';

    Scalar::Util::weaken( my $ttt = $self );
    my $include_path = $self->config->{include_path};
    $tt_config{'INCLUDE_PATH'} ||= [
        ( defined $include_path ? $include_path : () ),
        sub { [ $ttt->views ] },
    ];

    my $tt = Template->new(%tt_config);
    $Template::Stash::PRIVATE = undef if $self->config->{show_private_variables};
    return $tt;
}

sub render {
    my ( $self, $template, $tokens ) = @_;

    my $content = '';
    my $charset = $self->charset;
    my @options = length($charset) ? ( binmode => ":encoding($charset)" ) : ();
    $self->engine->process( $template, $tokens, \$content, @options )
      or croak 'Failed to render template: ' . $self->engine->error;

    return $content;
}

# Override *_pathname methods from Dancer2::Core::Role::Template
# Let TT2 do the concatenation of paths to template names.
#
# TT2 will look in a its INCLUDE_PATH for templates.
# Typically $self->views is an absolute path, and we set ABSOLUTE=> 1 above.
# In that case TT2 does NOT iterate through what is set for INCLUDE_PATH
# However, if its not absolute, we want to allow TT2 iterate through the
# its INCLUDE_PATH, which we set to be $self->views.

sub view_pathname {
    my ( $self, $view ) = @_;
    return $self->_template_name($view);
}

sub layout_pathname {
    my ( $self, $layout ) = @_;
    return path(
        $self->layout_dir,
        $self->_template_name($layout),
    );
}

sub pathname_exists {
    my ( $self, $pathname ) = @_;
    my $exists = eval {
        # dies if pathname can not be found via TT2's INCLUDE_PATH search
        $self->engine->service->context->template( $pathname );
        1;
    };
    $self->log_cb->( debug => $@ ) if ! $exists;
    return $exists;
}

1;

__END__

=head1 SYNOPSIS

To use this engine, you may configure L<Dancer2> via C<config.yaml>:

    template:   "template_toolkit"

Or you may also change the rendering engine on a per-route basis by
setting it manually with C<set>:

    # code code code
    set template => 'template_toolkit';

Most configuration variables available when creating a new instance of a
L<Template>::Toolkit object can be declared inside the template toolkit
section on the engines configuration in your config.yml file.  For example:

  engines:
    template:
      template_toolkit:
        start_tag: '<%'
        end_tag:   '%>'

(Note: C<start_tag> and C<end_tag> are regexes.  If you want to use PHP-style
tags, you will need to list them as C<< <\? >> and C<< \?> >>.)
See L<Template::Manual::Config> for the configuration variables.

In addition to the standard configuration variables, the option C<show_private_variables>
is also available. Template::Toolkit, by default, does not render private variables
(the ones starting with an underscore). If in your project it gets easier to disable
this feature than changing variable names, add this option to your configuration.

        show_private_variables: true

B<Warning:> Given the way Template::Toolkit implements this option, different Dancer2
applications running within the same interpreter will share this option!

=head1 DESCRIPTION

This template engine allows you to use L<Template>::Toolkit in L<Dancer2>.

=method render($template, \%tokens)

Renders the template.  The first arg is a filename for the template file
or a reference to a string that contains the template. The second arg
is a hashref for the tokens that you wish to pass to
L<Template::Toolkit> for rendering.

=head1 ADVANCED CUSTOMIZATION

L<Template>::Toolkit allows you to replace certain parts, like the internal
STASH (L<Template::Stash>). In order to do that, one usually passes an object of another
implementation such as L<Template::Stash::AutoEscaping> into the constructor.

Unfortunately that is not possible when you configure L<Template>::Toolkit from
your Dancer2 configuration file. You cannot instantiate a Perl object in a yaml file.
Instead, you need to subclass this module, and use the subclass in your configuration file.

A subclass to use the aforementioned L<Template::Stash::AutoEscaping> might look like this:

    package Dancer2::Template::TemplateToolkit::AutoEscaping;
    # or MyApp::
    
    use Moo;
    use Template::Stash::AutoEscaping;
    
    extends 'Dancer2::Template::TemplateToolkit';
    
    around '_build_engine' => sub {
        my $orig = shift;
        my $self = shift;
    
        my $tt = $self->$orig(@_);
    
        # replace the stash object
        $tt->service->context->{STASH} = Template::Stash::AutoEscaping->new(
            $self->config->{STASH}
        );
    
        return $tt;
    };
    
    1;

You can then use this new subclass in your config file instead of C<template_toolkit>.

    # in config.yml
    engines:
      template:
        TemplateToolkit::AutoEscaping:
          start_tag: '<%'
          end_tag:   '%>'
          # optional arguments here
          STASH:

The same approach should work for SERVICE (L<Template::Service>), CONTEXT (L<Template::Context>),
PARSER (L<Template::Parser>) and GRAMMAR (L<Template::Grammar>). If you intend to replace
several of these components in your app, it is suggested to create an app-specific subclass
that handles all of them at the same time.

=head2 Template Caching

L<Template>::Tookit templates can be cached by adding the C<COMPILE_EXT> property to your
template configuration settings:

    # in config.yml
    engines:
      template:
        template_toolkit:
          start_tag: '<%'
          end_tag:   '%>'
          COMPILE_EXT: '.tcc' # cached file extension

Template caching will avoid the need to re-parse template files or blocks each time they are
used. Cached templates are automatically updated when you update the original template file.

By default, cached templates are saved in the same directory as your template. To save
cached templates in a different directory, you can set the C<COMPILE_DIR> property in your
Dancer2 configuration file. 

Please see L<Template::Manual::Config/Caching_and_Compiling_Options> for further
details and more caching options.
            
=head1 SEE ALSO

L<Dancer2>, L<Dancer2::Core::Role::Template>, L<Template::Toolkit>.
