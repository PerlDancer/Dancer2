use strict;
use warnings;
use Test::More tests => 39;

use_ok('Dancer2::Core::Runner');

is( $Dancer2::runner, undef, 'No runner defined in Dancer2 yet' );

{
    my $runner = Dancer2::Core::Runner->new();
    isa_ok( $runner, 'Dancer2::Core::Runner' );
}

note 'MIME types'; {
    my $runner = Dancer2::Core::Runner->new();
    can_ok( $runner, 'mime_type' );
    isa_ok( $runner->mime_type, 'Dancer2::Core::MIME' );
}

ok( $Dancer2::runner, 'Have a runner (probably) in $Dancer2::runner' );
isa_ok( $Dancer2::runner, 'Dancer2::Core::Runner', 'Runner now defined' );

note 'BUILD setting $Carp::Verbose';
{
    my $runner = Dancer2::Core::Runner->new();
    is( $runner->config->{'traces'}, 0, 'traces not turned on (default' );
    is( $Carp::Verbose, 0, 'Carp Verbose not turned on (default)' );
}

{
    local $ENV{DANCER_TRACES} = 1;
    my $runner = Dancer2::Core::Runner->new();
    is( $runner->config->{'traces'}, 1, 'traces turned on' );
    is( $Carp::Verbose, 1, 'Carp Verbose turned on (using DANCER_TRACES)' );
}

note 'server'; {
    my $runner = Dancer2::Core::Runner->new(
        host => '1.2.3.4', port => 9543, timeout => 3,
    );
    can_ok( $runner, qw<server _build_server run> );

    my $server = $runner->server;
    isa_ok( $server, 'HTTP::Server::PSGI' );
    can_ok( $server, 'run' );
    foreach my $attr ( qw<host port timeout> ) {
        is( $server->{$attr}, $runner->$attr, "$attr set correctly in Server" );
    }

    is(
        $server->{'server_software'},
        "Perl Dancer2 $Dancer2::VERSION",
        'server_software set correctly in Server',
    );
}

note 'Environment';
{
    my $runner = Dancer2::Core::Runner->new();

    is(
        $runner->environment,
        'development',
        'Default environment',
    );
}

{
    local $ENV{DANCER_ENVIRONMENT} = 'foo';
    my $runner = Dancer2::Core::Runner->new();
    is(
        $runner->environment,
        'foo',
        'Successfully set envinronment using DANCER_ENVIRONMENT',
    );

    $runner->config->{'apphandler'} = 'Standalone';
}

{
    local $ENV{PLACK_ENV} = 'bar';
    my $runner = Dancer2::Core::Runner->new();
    is(
        $runner->environment,
        'bar',
        'Successfully set environment using PLACK_ENV',
    );

    is(
        $runner->config->{'apphandler'},
        'PSGI',
        'apphandler set to PSGI under PLACK_ENV',
    );
}

{
    local $ENV{DANCER_APPHANDLER} = 'baz';
    my $runner = Dancer2::Core::Runner->new();
    is(
        $runner->config->{'apphandler'},
        'baz',
        'apphandler set via DANCER_APPHANDLER',
    );
}

note 'Server tokens';
{
    my $runner = Dancer2::Core::Runner->new();
    is(
        $runner->config->{'no_server_tokens'},
        0,
        'Default no_server_tokens',
    );
}

{
    local $ENV{DANCER_NO_SERVER_TOKENS} = 1;
    my $runner = Dancer2::Core::Runner->new();
    is(
        $runner->config->{'no_server_tokens'},
        1,
        'Successfully set no_server_tokens using DANCER_NO_SERVER_TOKENS',
    );
}

note 'Startup info';
{
    my $runner = Dancer2::Core::Runner->new();
    is(
        $runner->config->{'startup_info'},
        1,
        'Default startup_info',
    );
}

{
    local $ENV{DANCER_STARTUP_INFO} = 0;
    my $runner = Dancer2::Core::Runner->new();
    is(
        $runner->config->{'startup_info'},
        0,
        'Successfully set startup_info using DANCER_STARTUP_INFO',
    );
}

{
    {
        package App::Fake;
        use Moo;
        has name => (
            is      => 'ro',
            default => sub {__PACKAGE__},
        );

        has postponed_hooks => (
            is      => 'ro',
            default => sub { +{
                before => 'that',
                after  => 'this',
            } },
        );
    }
    my $runner = Dancer2::Core::Runner->new();
    my $app    = App::Fake->new();
    can_ok( $runner, qw<register_application add_postponed_hooks> );

    is_deeply(
        $runner->apps,
        [],
        'Apps are empty at first',
    );

    is_deeply(
        $runner->postponed_hooks,
        +{},
        'No postponed hooks at first',
    );

    $runner->register_application($app);

    is_deeply(
        $runner->apps,
        [$app],
        'Runner registered application',
    );

    is_deeply(
        $runner->postponed_hooks,
        { 'App::Fake' => $app->postponed_hooks },
        'Runner registered the App\'s postponed hooks',
    );
}

{
    my $runner = Dancer2::Core::Runner->new();
    can_ok( $runner, qw<start start_server> );

    $runner->config->{'apphandler'} = 'PSGI';
    my $app = $runner->start;
    isa_ok( $app, 'CODE' );

    {
        package Server::Fake;
        sub new { bless {}, 'Server::Fake' }
        sub run {
            my ( $self, $app ) = @_;
            ::isa_ok( $self, 'Server::Fake' );
            ::isa_ok( $app, 'CODE' );

            return 'OK';
        }
    }

    $runner->{'server'} = Server::Fake->new;
    my $res = $runner->start_server($app);
    is( $res, 'OK', 'start_server works' );
}

{
    my $runner = Dancer2::Core::Runner->new();
    can_ok( $runner, 'start' );

    $runner->config->{'apphandler'} = 'PSGI';
    my $app = $runner->start;
    isa_ok( $app, 'CODE' );
}

