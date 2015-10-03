use warnings;
use strict;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{
    package TestApp;
    use Dancer2;

    set views          => 't/issues/gh-936/views';
    set error_template => 'error';

    get '/does-not-exist' => sub {
        send_error "not found", 404;
    };
}

my $test = Plack::Test->create( Dancer2->psgi_app );

for my $path ( qw{does-not-exist anywhere} ) {
    subtest "$path" => sub {
        my $res = $test->request( GET "/$path" );

        is $res->code, 404, 'status is 404';
        like $res->content, qr{CUSTOM ERROR TEMPLATE GOES HERE},
            'Error message looks good';
    };
}

done_testing();

