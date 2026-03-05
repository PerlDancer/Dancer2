use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/";

use Test::More;

{
    package App1;
    use Dancer2;
    use TestPlugin;
    set logger => 'null';
    get '/' => sub {
        my @apps = test();
        ::is( $apps[0], $apps[1], 'Plugin reports the same app' );
        ::is( $apps[0], app->name, 'Plugin reports the correct app' );
        return 'Cookie: ' . (response()->headers()->header('Set-Cookie') // '');

    };

    package App2;
    use Dancer2;
    use TestPlugin;
    set logger => 'null';
    get '/' => sub {
        my @apps = test();
        ::is( $apps[0], $apps[1], 'Plugin reports the same app' );
        ::is( $apps[0], app->name, 'Plugin reports the correct app' );
        return 'Cookie: ' . (response()->headers()->header('Set-Cookie') // '');
    };
}

use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;

my $app1 = Plack::Test->create( App1->to_app() );
my $app2 = Plack::Test->create( App2->to_app() );

my $cookie = $app1->request(GET '/')->header('Set-Cookie');
is($cookie, 'App1=foo; Path=/', 'Got cookie from app1');
$cookie = $app2->request(GET '/')->header('Set-Cookie');
is($cookie, 'App2=foo; Path=/', 'Got cookie from app2');
$cookie = $app1->request(GET '/')->header('Set-Cookie');
is($cookie, 'App1=foo; Path=/', 'Got cookie again from app1');

done_testing();
