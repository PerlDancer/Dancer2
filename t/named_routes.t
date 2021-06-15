use strict;
use warnings;
use Test::More 'tests' => 5;
use Plack::Test;
use HTTP::Request::Common;

{
    package MyApp;

    use Dancer2;

    # Name, Regexp, Code
    get 'view_static', '/view' => sub {
        'View Static';
    };

    get 'view_regex', qr{^/view_r$} => sub {
        'View Regex'
    };

    # Name, Regexp, Options, Code
    get 'base_static', '/' => { 'user_agent' => 'XX' }, sub {
        'Base Static';
    };

    # Name, Regexp, Options, Code
    get 'base_regex', qr{^/r$} => { 'user_agent' => 'XX' }, sub {
        'Base Regex';
    };

    get '/ignore1' => sub {1};
    get '/ignore2' => sub {1};
    get '/ignore3' => sub {1};
}

my $test = Plack::Test->create( MyApp->to_app );

subtest 'Named route' => sub {
    plan 'tests' => 2;

    my $response = $test->request( GET '/view' );
    ok( $response->is_success, 'Successfully reached /view' );
    is( $response->content, 'View Static', 'Static route with name' );
};

subtest 'Named regex route' => sub {
    plan 'tests' => 2;

    my $response = $test->request( GET '/view_r' );
    ok( $response->is_success, 'Successfully reached /view_r' );
    is( $response->content, 'View Regex', 'Regex route with name' );
};

subtest 'Named route with options' => sub {
    plan 'tests' => 2;

    my $response = $test->request( GET '/', 'User-Agent' => 'XX' );
    ok( $response->is_success, 'Successfully reached /' );
    is($response->content, 'Base Static',
        'Static route with name and options');
};

subtest 'Named regex route with options' => sub {
    plan 'tests' => 2;

    my $response = $test->request( GET '/r', 'User-Agent' => 'XX' );
    ok( $response->is_success, 'Successfully reached /r' );
    is($response->content, 'Base Regex', 'Regex route with name and options');
};

subtest 'Route objects' => sub {
    plan 'tests' => 3;

    my @apps = @{ Dancer2::runner->apps };
    is( scalar @apps, 1, 'Only one app exists' );

    my @routes = @{ $apps[0]->routes->{'get'} };
    is( scalar @routes, 7, 'Five routes registered' );

    is_deeply(
        [ map $_->name, @routes ],
        [
            'view_static',
            'view_regex',
            'base_static',
            'base_regex',
            0, # /ignore1 (0) + HEAD (Plack::Middleware::Head) (1)
            2, # /ignore2 (2) + HEAD (Plack::Middleware::Head) (3)
            4, # /ignore3 (4) + HEAD (Plack::Middleware::Head) (5)
        ],
        'All the right route names',
    );
};
