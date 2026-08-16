package Dancer2::Handler::AutoPage;
# ABSTRACT: Class for handling the AutoPage feature

use Moo;
use Carp 'croak';
use Dancer2::Core::Types;
use Path::Tiny ();

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

        # Cheap fast path: if the request path is spelled with the layout
        # directory's own case, refuse it without touching the filesystem.
        # This is only an optimisation - it is not the authoritative check,
        # because on a case-insensitive filesystem (macOS/Windows) a
        # differently-cased request would miss it while still resolving to
        # the same file. The check below decides from the resolved
        # file instead, so it catches that case too.
        if ( defined $layout_dir && $page =~ m{^/\Q$layout_dir\E/} ) {
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

        # Authoritative check: is the page's own directory, resolved on
        # disk, inside the layout directory? Decided from what is actually
        # there rather than the request path's spelling, the same
        # containment approach send_file uses at
        # Dancer2/Core/App.pm:1180-1182
        # ($dir->realpath->subsumes($file_path)).
        #
        # This does not use $view_path/view_pathname for the comparison:
        # that method is engine-specific, and Dancer2::Template::TemplateToolkit
        # overrides it to return a bare template name rather than a
        # filesystem path, leaving TT2's own INCLUDE_PATH search to resolve
        # it - so it cannot be relied on to name a location on disk here.
        # $template->views is guaranteed absolute by
        # Dancer2::Core::Role::Template, so joining it with $page and
        # taking the parent gives the page's real directory regardless of
        # which template engine is in use. Its parent directory is
        # guaranteed to exist at this point - pathname_exists just
        # confirmed the page resolves to a real file - so realpath cannot
        # die here.
        if ( defined $layout_dir ) {
            my $layout_dir_path =
                Path::Tiny::path( $template->views, $layout_dir );
            my $page_dir_path =
                Path::Tiny::path( $template->views, $page )->parent;

            if ( $layout_dir_path->is_dir
                && $page_dir_path->is_dir
                && $layout_dir_path->realpath->subsumes(
                    $page_dir_path->realpath
                )
            ) {
                $app->response->has_passed(1);
                return;
            }
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
