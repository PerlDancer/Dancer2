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

        # Authoritative check: is the page's own directory the layout
        # directory, or inside it? Decided from what is actually on disk
        # rather than from the request path's spelling.
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
        # confirmed the page resolves to a real file.
        if ( defined $layout_dir ) {
            my $layout_dir_path =
                Path::Tiny::path( $template->views, $layout_dir );
            my $page_dir_path =
                Path::Tiny::path( $template->views, $page )->parent;

            if ( $layout_dir_path->is_dir
                && $page_dir_path->is_dir
                && _dir_is_within(
                    $page_dir_path,
                    $layout_dir_path,
                    Path::Tiny::path( $template->views ),
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

# Is $dir the same directory as $ancestor, or inside it?
#
# Comparing resolved path strings is not enough. realpath() resolves
# symlinks but does not canonicalise case, so on a case-insensitive
# filesystem - macOS and Windows by default - 'views/Layouts' and
# 'views/layouts' name one directory while comparing as two. That is
# precisely the case this guard exists to catch, so the comparison is made
# on filesystem identity (device and inode) instead, which no spelling can
# disguise. It settles symlinks and hardlinks on the way past.
#
# The walk stops at $stop_at (the views directory) rather than climbing to
# the filesystem root: nothing above views is ours to reason about, and a
# page cannot be inside the layout directory without being under views too.
#
# Some Windows configurations report an inode of 0 for every file, which
# would make every directory compare equal to every other. Where that is
# so, identity is unusable and the comparison falls back to matching the
# paths case-insensitively - imperfect, since it assumes the folding rules
# rather than asking the filesystem, but it fails closed on the case this
# guard is about rather than silently passing everything.
sub _dir_is_within {
    my ( $dir, $ancestor, $stop_at ) = @_;

    my @ancestor_id = stat "$ancestor" or return 0;
    my $usable_inode = $ancestor_id[1];

    if ( !$usable_inode ) {
        my $a = lc Path::Tiny::path($ancestor)->stringify;
        my $d = lc Path::Tiny::path($dir)->stringify;
        return $d eq $a || index( $d, "$a/" ) == 0;
    }

    my $stop = eval { $stop_at->realpath->stringify };
    my $cursor = eval { $dir->realpath } or return 0;

    while (1) {
        my @id = stat "$cursor" or return 0;
        # 'eq', not '=='. Where an inode number is too large for perl to
        # hold as an integer, stat returns it as a decimal string; comparing
        # numerically converts that to a float and rounds it, so two
        # different inodes can compare equal. perldoc -f stat says to prefer
        # 'eq' for exactly this reason, and it is correct for the values
        # that are returned numerically too. Rounding here would be a
        # fail-open: a page outside the layout directory would be served.
        return 1 if $id[0] eq $ancestor_id[0] && $id[1] eq $ancestor_id[1];

        last if defined $stop && $cursor->stringify eq $stop;

        my $parent = $cursor->parent;
        last if $parent->stringify eq $cursor->stringify;    # hit the root
        $cursor = $parent;
    }

    return 0;
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
