package contrib::lib::Bar;

use Dancer 2.0;
use Data::Dumper;

prefix '/bar';

set in_bar => 1;

get '/' => sub { "/bar" };

get '/config' => sub { Dumper(config) };

get '/see_session_in_template' => sub {
    session bar_session => "foo";
    var bar_var => "foo";
    template "tokens";
};

1;
