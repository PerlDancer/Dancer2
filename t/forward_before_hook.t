use strict;
use warnings;
use Test::More import => ['!pass'], tests => 4;
use Dancer2;
use Plack::Test;
use HTTP::Request::Common;

get '/' => sub {
    return 'Forbidden';
};

get '/default' => sub {
    return 'Default';
};

get '/redirect' => sub {
    return 'Secret stuff never seen';
};

hook before => sub {
    my $context = shift;
    return if $context->request->dispatch_path eq '/default';

    # Add some content to the response
    $context->response->content("SillyStringIsSilly");

    # redirect - response should include the above content
    return redirect '/default'
        if $context->request->dispatch_path eq '/redirect';

    # The response object will get replaced by the result of the forward.
    forward '/default';
};

my $app = Dancer2->runner->server->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    like(
        $cb->( GET '/' )->content,
        qr{Default},
        'forward in before hook',
    );

    my $r = $cb->( GET '/redirect' );

    # redirect in before hook
    is( $r->code, 302, 'redirect in before hook' );
    is(
        $r->content,
        'SillyStringIsSilly',
        '.. and the response content is correct',
    );
};

done_testing();
