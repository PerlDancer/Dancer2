use strict;
use warnings;
use Test::More 'tests' => 3;
use Plack::Test;
use HTTP::Request::Common;

{
    package Dancer2::Plugin::Foo;
    use Dancer2::Plugin;

    BEGIN {
        has 'foo_message' => (
            'is'      => 'ro',
            'default' => sub {'foo'},
        );

        plugin_keywords('foo_message');
    }
}

{
    package Dancer2::Plugin::Bar;
    use Dancer2::Plugin;

    BEGIN {
        has 'bar_message' => (
            'is'      => 'ro',
            'lazy'    => 1,
            'default' => sub {
                my $self = shift;
                ::isa_ok( $self, 'Dancer2::Plugin::Bar' );

                my $foo = $self->find_plugin('Dancer2::Plugin::Foo')
                    or Carp::croak('Cannot find Dancer2::Plugin::Foo');

                ::isa_ok( $foo, 'Dancer2::Plugin::Foo' );
                ::can_ok( $foo, 'foo_message' );
                return $foo->foo_message . ':bar';
            }
        );

        plugin_keywords('bar_message');
    }
}

{
    package AppWithFoo;
    use Dancer2;
    use Dancer2::Plugin::Foo;
    get '/' => sub { return foo_message() };
}

{
    package AppWithBar;
    use Dancer2;
    use Dancer2::Plugin::Bar;
    set 'logger' => 'Capture';
    get '/' => sub { return bar_message() };
}

{
    package AppWithFooAndBar;
    use Dancer2;
    use Dancer2::Plugin::Foo;
    use Dancer2::Plugin::Bar;
    get '/' => sub { return bar_message() };
}

subtest 'Baseline' => sub {
    my $test = Plack::Test->create( AppWithFoo->to_app );
    my $res  = $test->request( GET '/' );
    ok( $res->is_success, 'Successful response' );
    is( $res->content, 'foo', 'Foo plugin works correctly' );
};

subtest 'When parent plugin not available' => sub {
    my $test = Plack::Test->create( AppWithBar->to_app );
    my $res  = $test->request( GET '/' );

    ok( !$res->is_success, 'Response failed' );

    my $trap = AppWithBar::app->config()->{'logger'};
    isa_ok( $trap, 'Dancer2::Logger::Capture' );

    my $trapper = $trap->trapper;
    my $logs    = $trapper->read;
    isa_ok( $logs, 'ARRAY', 'Found logs' );
    is( scalar @{$logs}, 1, 'One log message' );

    my $message = $logs->[0];
    is( $message->{'level'}, 'error' );
    like(
        $message->{'message'},
        qr{\QRoute exception: Cannot find Dancer2::Plugin::Foo\E},
        'Correct error',
    );
};

subtest 'When both parent and child plugins available' => sub {
    my $test = Plack::Test->create( AppWithFooAndBar->to_app );
    my $res  = $test->request( GET '/' );
    ok( $res->is_success, 'Successful response' );
    is( $res->content, 'foo:bar', 'Bar plugin found Foo and worked' );
};
