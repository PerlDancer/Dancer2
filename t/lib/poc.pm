package poc;
use Dancer2;

our $VERSION = '0.1';

set plugins => {
    Foo => {
        one => 1,
        two => 2,
        size => 4,
    },
};

=pod

:app will make the app load the plugin (via 'with_plugins')
and will export the plugin keywords to this namespace

without ':app', it's just a regular 'use' statement

=cut

use Dancer2::Plugin::Foo ':app';
                                

get '/' => sub {
    return 'hello there';
};

get '/truncate' => sub { truncate_txt "hello there" };

true;
