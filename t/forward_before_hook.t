use Test::More import => ['!pass'], tests => 3;
use Dancer2;
use Dancer2::Test;
use strict;
use warnings;


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

response_content_like(
    [ GET => '/' ], qr{Default},
    'forward in before hook'
);

# redirect in before hook
my $r = dancer_response GET => '/redirect';
is $r->status, 302, "redirect in before hook";
is $r->content, "SillyStringIsSilly",
    ".. and the response content is correct";

done_testing();
