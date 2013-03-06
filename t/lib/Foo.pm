package t::lib::Foo;
use Dancer2;

get '/in_foo' => sub {
    session('test');
};

1;
