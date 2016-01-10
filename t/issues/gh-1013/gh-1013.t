use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Plack::Test;
use HTTP::Request::Common;

{
    ## no critic
    package TestApp;
    use Dancer2;

    my $app = app;
    hook before_template => sub {
        1;
    };

    set template => 'simple';

    get '/' => sub {
        template t => { hi => 'hello' },
    };
};

my $test = Plack::Test->create( TestApp->to_app );

my $res;
is(
    exception { $res = $test->request( GET '/' ); },
    undef,
    'Request does not crash',
);

ok( $res->is_success, 'Request successful' );

chomp( my $content = $res->content );
is( $content, 'hello', 'Correct content' );

done_testing;
