use strict;
use warnings;
use Test::More;

BEGIN {
    use Dancer 2.0;
    set session => 'Simple';
    engine('session')->{'__marker__'} = 1;
}

use t::lib::Foo with => { session => engine('session') };

use Data::Dumper;

get '/main' => sub {
    session('test' => 42);
};

use Dancer::Test 'main', 't::lib::Foo';

response_content_like "/main", qr{42}, "session is set in main";
response_content_like "/in_foo", qr{42}, "... and is also set in Foo app";

my $engine = t::lib::Foo->dsl->engine('session');
is $engine->{__marker__}, 1, "the session engine in subapp is the same";

done_testing;
