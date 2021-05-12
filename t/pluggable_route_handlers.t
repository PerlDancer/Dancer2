use strict;
use warnings;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;

package Dancer2::Handler::TestHandler {
    use Moo::Role;
    with 'Dancer2::Core::Role::Handler';

    sub regexp {'/**?'}
    sub methods {'get'}

    sub register {
        my ( $self, $app ) = @_;
        return unless $app->config->{test_handler};

        $app->add_route(
            method => $_,
            regexp => $self->regexp,
            code   => $self->code,
        ) for $self->methods;
    }

    sub code { sub {'I was handled'} }
};


package TestApp {
    use Dancer2;
    use Dancer2::Handler::TestHandler;

    set config => {
        route_handlers => [[ TestHandler => 1 ]],
        test_handler => 1,
    };
};

my $app = TestApp->to_app;

test_psgi $app, sub {
    my $cb = shift;
    my $res  = $cb->( GET '/foo' );

    TODO: {
        local $TODO = "Route handlers not loaded correctly under to_app";
        ok( $res->is_success,                 'request to /foo was successful' );
        is( $res->content, 'I was handled',   'page content is as expected' );
    };
};
