use utf8;
use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Encode;

my $utf8 = 'ľščťžýáí';

{
    package MyApp;

    use Dancer2;
    use utf8;

    get '/ľščťžýáí' => sub {
        return 'ľščťžýáí';
    };
}

my $app = Dancer2->psgi_app;

test_psgi $app, sub {
    my $cb = shift;

    my $res = $cb->( GET '/ľščťžýáí' );
    is $res->code, 200;
    is Encode::decode('utf8', $res->content), 'ľščťžýáí';
};

done_testing();
