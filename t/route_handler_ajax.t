#test ported from Dancer 1's t/03_route_handler/21_ajax.t
use strict;
use warnings;
use Test::More;
use Dancer 2.0;
use Dancer::Plugin::Ajax;
use Dancer::Test;
use Test::TCP 1.13;
use LWP::UserAgent;

#there is no single method in Dancer 2 like registry->is_empty
my $empty = {
    'head'    => [],
    'options' => [],
    'del'     => [],
    'post'    => [],
    'get'     => [],
    'put'     => []
};
my $app = dancer_app;
is_deeply($app->routes, $empty, 'route registry is empty');
ajax '/' => sub {'ajax'};
isnt($app->routes, $empty, 'route registry is NOT empty');

my $server = Test::TCP->new(
    code => sub {
        my $port = shift;
        set(startup_info => 0, layout => 'wibble');
        Dancer->runner->server->port($port);

        ajax '/req' => sub {
            return 1;
        };
        get '/foo' => sub {
            return 'not ajax';
        };
        ajax '/foo' => sub {
            return 'ajax';
        };
        get '/bar' => sub {
            return 'not ajax';
        };
        get '/bar', {ajax => 1} => sub {
            return 'ajax';
        };
        get '/ajax.json' => sub {
            content_type('application/json');
            return '{"foo":"bar"}';
        };
        ajax '/die' => sub {
            die;
        };
        get '/layout' => sub {
            return setting 'layout';
        };
        start;
    },
);

#client
my $port = $server->port;
my $ua   = LWP::UserAgent->new;

my @queries = (
    {path => 'req', ajax => 1, success => 1, content => 1},
    {path => 'req', ajax => 0, success => 0},
    {path => 'foo', ajax => 1, success => 1, content => 'ajax'},
    {path => 'foo', ajax => 0, success => 1, content => 'not ajax'},
    {path => 'bar', ajax => 1, success => 1, content => 'ajax'},
    {path => 'bar', ajax => 0, success => 1, content => 'not ajax'},
    {   path    => 'layout',
        ajax    => 0,
        success => 1,
        content => 'wibble'
    },
    {path => 'die', ajax => 1, success => 0},
    {   path    => 'layout',
        ajax    => 0,
        success => 1,
        content => 'wibble'
    },
);

foreach my $query (@queries) {
    ok my $request =
      HTTP::Request->new(GET => "http://127.0.0.1:$port/" . $query->{path});

    $request->header('X-Requested-With' => 'XMLHttpRequest')
      if ($query->{ajax} == 1);

    ok my $res = $ua->request($request);

    if ($query->{success} == 1) {
        ok $res->is_success;
        is $res->content, $query->{content};
        like $res->header('Content-Type'), qr/text\/xml/
          if $query->{ajax} == 1;
    }
    else {
        ok !$res->is_success;
    }
}

# test ajax with content_type to json
ok my $request = HTTP::Request->new(GET => "http://127.0.0.1:$port/ajax.json");
$request->header('X-Requested-With' => 'XMLHttpRequest');
ok my $res = $ua->request($request);
like $res->header('Content-Type'), qr/json/;

done_testing
