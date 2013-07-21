# ABSTRACT: a plugin for adding Ajax route handlers

package Dancer2::Plugin::Ajax;

use strict;
use warnings;

use Dancer2;
use Dancer2::Plugin;

=head1 SYNOPSIS

    package MyWebApp;

    use Dancer2;
    use Dancer2::Plugin::Ajax;

    ajax '/check_for_update' => sub {
        # ... some Ajax code
    };

    dance;

=head1 DESCRIPTION

The C<ajax> keyword which is exported by this plugin allow you to define a route
handler optimized for Ajax queries.

The route handler code will be compiled to behave like the following:

=over 4

=item *

Pass if the request header X-Requested-With doesnt equal XMLHttpRequest

=item *

Disable the layout

=item *

The action built is a POST request.

=back

=cut

on_plugin_import {
    my $dsl = shift;
    $dsl->app->add_hook(
        Dancer2::Core::Hook->new(
            name => 'before',
            code => sub {
                if ( $dsl->request->is_ajax ) {
                    $dsl->request->content_type('text/xml');
                }
            }
        )
    );
};

register 'ajax' => sub {
    my ( $dsl, $pattern, @rest ) = @_;

    my $code;
    for my $e (@rest) { $code = $e if ( ref($e) eq 'CODE' ) }

    my $ajax_route = sub {

        # must be an XMLHttpRequest
        if ( not $dsl->request->is_ajax ) {
            $dsl->pass and return 0;
        }

        # disable layout
        my $layout = $dsl->setting('layout');
        $dsl->setting( 'layout' => undef );
        my $response = $code->();
        $dsl->setting( 'layout' => $layout );
        return $response;
    };

    $dsl->any( [ 'get', 'post' ] => $pattern, $ajax_route );
};

register_plugin;
1;


