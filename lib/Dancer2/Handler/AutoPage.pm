package Dancer2::Handler::AutoPage;
# ABSTRACT: Class for handling the AutoPage feature

use Moo;
use Carp 'croak';
use Dancer2::Core::Types;

with qw<
    Dancer2::Core::Role::Handler
    Dancer2::Core::Role::StandardResponses
>;

sub register {
    my ( $self, $app ) = @_;

    return unless $app->config->{auto_page};

    $app->add_route(
        method => $_,
        regexp => $self->regexp,
        code   => $self->code,
    ) for $self->methods;
}

sub code {
    sub {
        my $app    = shift;
        my $prefix = shift;

        my $template = $app->template_engine;
        if ( !defined $template ) {
            $app->response->has_passed(1);
            return;
        }

        my $page       = $app->request->path;
        my $layout_dir = $template->layout_dir;
        if ( $page =~ m{^/\Q$layout_dir\E/} ) {
            $app->response->has_passed(1);
            return;
        }

        # remove leading '/', ensuring paths relative to the view
        $page =~ s{^/}{};
        my $view_path = $template->view_pathname($page);

        if ( ! $template->pathname_exists( $view_path ) ) {
            $app->response->has_passed(1);
            return;
        }

        my $ct = $template->process( $page );
        return ( $app->request->method eq 'GET' ) ? $ct : '';
    };
}

sub regexp {'/**'}

sub methods {qw(head get)}

1;

__END__

=pod

=head1 DESCRIPTION

The AutoPage feature is a Handler (turned off by default) that is
responsible for serving pages that match an existing template. If a
view exists with a name that matches the requested path, Dancer2
processes the request using the Autopage handler.

To turn it add to your config file:

      auto_page: 1

This allows you to easily serve simple pages without having to write a
route definition for them.

If there's no view with the name request, the route passes, allowing
other matching routes to be dispatched.

=head1 METHODS

=head2 register

Creates the routes.

=head2 code

A code reference that processes the route request.

=head2 methods

The methods that should be served for autopages.

Default: B<head>, B<get>.

=head2 regexp

The regexp (path) we want to match.

Default: B</:page>.
