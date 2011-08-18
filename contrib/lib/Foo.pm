package contrib::lib::Foo;

use Dancer;

prefix "/contrib/foo";

get '/' => sub { "in contrib::lib::Foo" };
get '/hello' => sub { "in contrib::lib::Foo /foo/hello" };

1;
