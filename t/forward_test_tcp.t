use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;

    get '/' => sub {
        'home:' . join( ',', params );
    };

    get '/bounce/' => sub { forward '/' };

    get '/bounce/:withparams/' => sub { forward '/' };

    get '/bounce2/adding_params/' => sub {
        forward '/', { withparams => 'foo' };
    };

    get '/go_to_post/' => sub {
        forward '/simple_post_route/',
            { foo => 'bar' },
            { method => 'post' };
    };

    post '/simple_post_route/' => sub {
        'post:' . join( ',', params );
    };

    post '/' => sub {'post-home'};

    post '/bounce/' => sub { forward '/'  };
}

my $app = Dancer2->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    my $res = $cb->(GET "/");
    is $res->code      => 200;
    like $res->content => qr/home:/;

    $res = $cb->(GET "/bounce/");
    is $res->code      => 200;
    like $res->content => qr/home:/;

    $res = $cb->(GET "/bounce/thesethings/");
    is $res->code    => 200;
    is $res->content => 'home:withparams,thesethings';

    $res = $cb->(GET "/bounce2/adding_params/");
    is $res->code    => 200;
    is $res->content => 'home:withparams,foo';

    $res = $cb->(GET "/go_to_post/");
    is $res->code    => 200;
    is $res->content => 'post:foo,bar';

    $res = $cb->(GET "/bounce/");
    is $res->header('Content-Length') => 5;
    is $res->header('Content-Type')   => 'text/html; charset=UTF-8';
    is $res->header('Server')         => "Perl Dancer2 $Dancer2::VERSION";

    $res = $cb->(POST "/");
    is $res->code    => 200;
    is $res->content => 'post-home';

    $res = $cb->(POST "/bounce/");
    is $res->code                     => 200;
    is $res->content                  => 'post-home';
    is $res->header('Content-Length') => 9;
    is $res->header('Content-Type')   => 'text/html; charset=UTF-8';
    is $res->header('Server')         => "Perl Dancer2 $Dancer2::VERSION";
};

done_testing();
