package t::lib::Foo;
use Dancer 2.0;

get '/in_foo' => sub {
    session('test');
};

1;
