package contrib::lib::Bar;

use Dancer;
use Data::Dumper;

prefix '/bar';

set in_bar => 1;

get '/' => sub { "/bar" };

get '/config' => sub { Dumper(config) };

1;
