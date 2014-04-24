use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{

    package PrettyError;

    use Dancer2;

    engine('template')->views('t/corpus/pretty');
    $ENV{DANCER_PUBLIC} = 't/corpus/pretty_public';

    get '/error' => sub {
        send_error "oh my", 505;
    };

    get '/public' => sub {
        send_error "static", 510;
    };

    get '/no_template' => sub {
        local $ENV{DANCER_PUBLIC} = undef;

        send_error "oopsie", 404;
    };

}

my $app = Dancer2->runner->server->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    subtest "/error" => sub {
        my $r = $cb->( GET '/error' );

        is $r->code, 505, 'send_error sets the status to 505';
        like $r->content, qr{Template selected}, 'Error message looks good';
        like $r->content, qr{message: oh my};
        like $r->content, qr{status: 505};
    };

    subtest "/public" => sub {
        my $r = $cb->( GET '/public' );

        is $r->code,    510,             'send_error sets the status to 510';
        like $r->content, qr{Static page}, 'Error message looks good';
    };

    subtest "/no_template" => sub {
        my $r = $cb->( GET '/no_template' );

        is $r->code, 404, 'send_error sets the status to 404';
        like $r->content, qr{<h1>Error 404 - Not Found</h1>},
          'Error message looks good';
    };

    subtest '404 with static template' => sub {
        my $r = $cb->( GET '/middle/of/nowhere' );

        is $r->code, 404, 'unknown route => 404';
        like $r->content, qr{you're lost}i, 'Error message looks good';
    };
};

done_testing;
