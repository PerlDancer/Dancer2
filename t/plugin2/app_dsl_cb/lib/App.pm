package App;
use strict;
use warnings;
use Dancer2 appname => 'Other';
use App::TestPlugin;

get '/' => sub {
    my $res = foo_from_plugin('Foo');
    ::is( $res, 'OK', 'Plugin returned OK' );
    return 'GET DONE';
};

1;
