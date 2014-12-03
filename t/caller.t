#!perl

use strict;
use warnings;

use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;
use File::Spec;

{
    package App;
    use Dancer2;

    get '/' => sub { app->caller };

}

my $app = App->to_app;
test_psgi $app, sub {
    my $cb  = shift;
    my $res = $cb->( GET '/' );

    is( $res->code, 200, '[GET /] Successful' );
    is(
        File::Spec->canonpath( $res->content),
        File::Spec->catfile(t => 'caller.t'),
        'Correct App name from caller',
    );
};
