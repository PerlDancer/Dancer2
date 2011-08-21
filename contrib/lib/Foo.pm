package contrib::lib::Foo;

use Dancer;
use Data::Dumper;

prefix "/foo";

set in_foo => 1;

get '/' => sub { "in contrib::lib::Foo" };
get '/hello' => sub { "in contrib::lib::Foo /foo/hello" };

get '/config' => sub { Dumper(config) };

1;
