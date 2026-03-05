package poc;
use Dancer2;

our $VERSION = '0.1';

use Dancer2::Plugin::Foo;

set plugins => {
    Foo => {
        one => 1,
        two => 2,
        size => 4,
    },
};

get '/' => sub {
    return 'hello there';
};

get '/truncate' => sub { truncate_txt "hello there" };

true;
