package contrib::lib::Foo;

use Dancer;

prefix "/foo";

get '/' => sub { "/foo" };
get '/hello' => sub { "/foo/hello" };

1;
