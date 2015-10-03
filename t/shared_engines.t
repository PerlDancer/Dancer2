use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Cookies;
use HTTP::Request::Common;

{
    package App;

    # call stuff before next use() statement
    BEGIN {
        use Dancer2;
        set session => 'Simple';
        engine('session')->{'__marker__'} = 1;
    }

    use t::lib::Foo with => { session => engine('session') };

    get '/main' => sub {
        session( 'test' => 42 );
    };
}

my $jar = HTTP::Cookies->new;
my $url = 'http://localhost';

{
    my $test = Plack::Test->create( App->to_app );
    my $res  = $test->request( GET "$url/main" );
    like $res->content, qr{42}, "session is set in main";
    $jar->extract_cookies($res);

    ok( $jar->as_string, 'Got cookie' );
}

{
    my $test = Plack::Test->create( t::lib::Foo->to_app );
    my $req  = GET "$url/in_foo";
    $jar->add_cookie_header($req);

    my $res = $test->request($req);
    like $res->content, qr{42}, "session is set in foo";
}

my $engine = t::lib::Foo->dsl->engine('session');
is $engine->{__marker__}, 1,
  "the session engine in subapp is the same";

done_testing;
