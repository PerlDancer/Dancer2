use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{
    package FourOhFour;

    use Dancer2;

    set views      => 't/issues/gh-762/views';

    get '/error' => sub {
        send_error "oh my", 404;
    };

}

my $fourohfour_app = FourOhFour->to_app;
my $fourohfour_test   = Plack::Test->create($fourohfour_app);

subtest "/error" => sub {
    my $res = $fourohfour_test->request( GET '/error' );

    is $res->code, 404, 'send_error sets the status to 404';
    like $res->content, qr{Template selected}, 'Error message looks good';
    like $res->content, qr{message: oh my};
    like $res->content, qr{status: 404};
};

subtest 'FourOhFour with views template' => sub {
    my $path = "/middle/of/nowhere";
    my $res = $fourohfour_test->request( GET $path );

    is $res->code, 404, 'unknown route => 404';
    like $res->content, qr{Template selected}, 'Error message looks good';
    like $res->content, qr{message: $path};
    like $res->content, qr{status: 404};
};

done_testing();

