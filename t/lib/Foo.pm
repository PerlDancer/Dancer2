package t::lib::Foo;
use Dancer2;

get '/in_foo' => sub {
    use YAML::XS;warn Dump engine('session');
    session('test');
};

1;
