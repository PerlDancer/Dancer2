package t::lib::Foo;
use Dancer;

get '/in_foo' => sub {
    session('test');
};

1;
