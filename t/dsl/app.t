use strict;
use warnings;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;
    get '/' => sub {
        my $app = app;
        ::isa_ok( $app, 'Dancer2::Core::App' );
        ::is( $app->name, 'App', 'Correct app name' );
    };
}

Plack::Test->create( App->to_app )->request( GET '/' );

