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

    # Mappings, fade out at some stage, was there an intent to make them the same as
    # the tags for Dancer2::Template::Simple?
    my %legacy = (
      INCLUDE_PATH => ['include_path'],
      END_TAG => ['stop_tag', 'end_tag'],
      START_TAG => ['start_tag'],
    );
    while (my ($key, $aliases) = each %legacy) {
      foreach my $alias (@$aliases) {
        if (exists $self->config->{$alias}) {
          $self->log_cb()->('debug' => 
            "deprecated: please update your config '$alias' should be '$key'");
          $tt_config{$key} = $self->config->{$alias};
        }
      }
    }

    Scalar::Util::weaken( my $ttt = $self );
    $tt_config{'INCLUDE_PATH'} ||= [ sub { [ $ttt->views ] }, ];

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
# In that case TT2 does NOT itetare through what is set for INCLUDE_PATH
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
    return eval {
        # dies if pathname can not be found via TT2's INCLUDE_PATH search
        $self->engine->service->context->template( $pathname );
        1;
    };
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
section on the engines configuration (see your config.yml file):

  engines:
    template:
      template_toolkit:
        start_tag: '<%'
        end_tag:   '%>'

In addition to the standard configuration variables, the option C<show_private_variables>
is also available. Template::Toolkit, by default, do not render private variables
(the ones starting with an underscore). If in your project it gets easier to disable
this feature than changing variable names, add this option to your configuration.

        show_private_variables: true

B<Warning:> Given the way Template::Toolkit implements this option, different Dancer2
applications running within the same interpreter will share this option!

=head1 DESCRIPTION

This template engine allows you to use L<Template>::Toolkit in L<Dancer2>.

=method render($template, \%tokens)

Renders the template.  The first arg is a filename for the template file
or a reference to a string that contains the template.  The second arg
is a hashref for the tokens that you wish to pass to
L<Template::Toolkit> for rendering.

=head1 SEE ALSO

L<Dancer2>, L<Dancer2::Core::Role::Template>, L<Template::Toolkit>.
