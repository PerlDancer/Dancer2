use strict;
use warnings;
use Test::More 'tests' => 2;
use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;
    get '/' => sub { return uri_for('/foo'); };
}

{
    package MountedApp;
    use Dancer2;
    get '/' => sub { return uri_for('/bar'); };
}

my $prefix = 'http://localhost';

subtest 'Non-mounted app' => sub {
    my $app = Plack::Test->create( App->to_app );
    my $res;

    $res = $app->request( GET "$prefix/" );
    ok( $res->is_success, 'Successful request' );
    is( $res->content, "$prefix/foo", 'Correct regular path' );
};

subtest 'Mounted app' => sub {
    my $app = Plack::Test->create(
        builder {
            mount '/mount' => MountedApp->to_app;
            mount '/'      => App->to_app;
        }
    );

    my $res;

    $res = $app->request( GET "$prefix/" );
    ok( $res->is_success, 'Successful request' );
    is( $res->content, "$prefix/foo", 'Correct mounted regular path' );

    $res = $app->request( GET "$prefix/mount" );
    ok( $res->is_success, 'Successful request' );
    is($res->content, "$prefix/mount/bar", 'Correct mounted regular path');
};
