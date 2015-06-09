package Dancer2::Handler::AutoPage;
# ABSTRACT: Class for handling the AutoPage feature
$Dancer2::Handler::AutoPage::VERSION = '0.159002';
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

        my $template = $app->engine('template');
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

        my $view_path = $template->view_pathname($page);

        if ( !-f $view_path ) {
            $app->response->has_passed(1);
            return;
        }

        my $ct = $template->process( $page );
        $app->response->header( 'Content-Length', length($ct) );
        return ( $app->request->method eq 'GET' ) ? $ct : '';
    };
}

sub regexp {'/**'}

sub methods {qw(head get)}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Handler::AutoPage - Class for handling the AutoPage feature

=head1 VERSION

version 0.159002

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

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
