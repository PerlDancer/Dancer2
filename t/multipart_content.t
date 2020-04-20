use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw<is_coderef>;

{
    package App;
    use Dancer2;

    get '/' => sub {1};
}

#
# Test for this issue: https://github.com/PerlDancer/Dancer2/issues/1507
# When a request comes with Content-Type: multipart/form-data with no boundary,
# Dancer currently wrongly returns HTTP code 500 Internal Server Error.
# It should return HTTP code 400 Bad Request.
# We also test that a request with Content-Type: multipart/form-data boundary=------boundary-------' returns 200.

my $app = App->to_app;
ok( is_coderef($app), 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    is(
        $cb->( GET '/' => 'Content-Type' => 'multipart/form-data' )->code,
        400,
        'multipart with incorrect boundary returns 400',
    );

        my $headers = 


    is(
        $cb->(
            GET '/' =>
                'Content-Type' =>
                'Content-Type: multipart/form-data boundary=------boundary-------',
        )->code,
        200,
        'Providing multipart with correct boundary works',
    );
};

done_testing();
