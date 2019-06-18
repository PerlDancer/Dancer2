use strict;
use warnings;
use Plack::Test;
use HTTP::Request::Common;
use Test::More 'tests' => 2;

{
    package Foo;
    use Dancer2;

    prepare_app {
        set 'app_1' => 'called 1';
    };

    get '/' => sub {'OK'};
}

{
    package Bar;
    use Dancer2 'appname' => 'Foo';

    prepare_app {
        set 'app_2' => 'called 2';
    };

    get '/' => sub {'OK'};
}

subtest 'Foo' => sub {
    my $app = Foo->to_app;
    is(
        Foo->config()->{'app_1'},
        'called 1',
        'App 1 had prepare_app called',
    );

    my $test = Plack::Test->create($app);
    my $res  = $test->request( GET '/' )->content();
    is(
        $res,
        'OK',
        'Correct content',
    );
};

subtest 'Bar' => sub {
    my $app = Bar->to_app;
    is(
        Bar->config()->{'app_2'},
        'called 2',
        'App 2 had prepare_app called',
    );

    my $test = Plack::Test->create($app);
    my $res  = $test->request( GET '/' )->content();
    is(
        $res,
        'OK',
        'Correct content',
    );
};
