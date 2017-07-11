package Dancer2::Core::Runner;
# ABSTRACT: Top-layer class to start a dancer app

use Moo;
use Carp 'croak';
use Module::Runtime 'require_module';
use Dancer2::Core::MIME;
use Dancer2::Core::Types;
use Dancer2::Core::Dispatcher;
use Plack::Builder qw();
use Ref::Util qw< is_ref is_regexpref >;

# Hashref of configurable items for the runner.
# Defaults come from ENV vars. Updated via global triggers
# from app configs.
has config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_config',
);

# FIXME: i hate this
has mime_type => (
    is      => 'ro',
    isa     => InstanceOf ['Dancer2::Core::MIME'],
    default => sub { Dancer2::Core::MIME->new(); },
);

has server => (
    is      => 'ro',
    isa     => InstanceOf['HTTP::Server::PSGI'],
    lazy    => 1,
    builder => '_build_server',
    handles => ['run'],
);

has apps => (
    is      => 'ro',
    isa     => ArrayRef,
    default => sub { [] },
);

has postponed_hooks => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { +{} },
);

has environment => (
    is       => 'ro',
    isa      => Str,
    required => 1,
    default  => sub {
        $ENV{DANCER_ENVIRONMENT} || $ENV{PLACK_ENV} || 'development'
    },
);

has host => (
    is      => 'ro',
    lazy    => 1,
    default => sub { $_[0]->config->{'host'} },
);

has port => (
    is      => 'ro',
    lazy    => 1,
    default => sub { $_[0]->config->{'port'} },
);

has timeout => (
    is      => 'ro',
    lazy    => 1,
    default => sub { $_[0]->config->{'timeout'} },
);

sub _build_server {
    my $self = shift;

    require_module('HTTP::Server::PSGI');
    HTTP::Server::PSGI->new(
        host            => $self->host,
        port            => $self->port,
        timeout         => $self->timeout,
        server_software => "Perl Dancer2 " . Dancer2->VERSION,
    );
}

sub _build_config {
    my $self = shift;

    $ENV{PLACK_ENV}
      and $ENV{DANCER_APPHANDLER} = 'PSGI';

    return {
        behind_proxy     => 0,
        apphandler       => ( $ENV{DANCER_APPHANDLER} || 'Standalone' ),
        traces           => ( $ENV{DANCER_TRACES}     || 0 ),
        host             => ( $ENV{DANCER_SERVER}     || '0.0.0.0' ),
        port             => ( $ENV{DANCER_PORT}       || '3000' ),
        no_server_tokens => ( defined $ENV{DANCER_NO_SERVER_TOKENS} ?
                              $ENV{DANCER_NO_SERVER_TOKENS}         :
                              0 ),
        startup_info     => ( defined $ENV{DANCER_STARTUP_INFO} ?
                              $ENV{DANCER_STARTUP_INFO}         :
                              1 ),
    };
}

sub BUILD {
    my $self = shift;

    # Enable traces if set by ENV var.
    if (my $traces = $self->config->{traces} ) {
        require_module('Carp');
        $Carp::Verbose = $traces ? 1 : 0;
    };

    # set the global runner object if one doesn't exist yet
    # this can happen if you create one without going through Dancer2
    # which doesn't trigger the import that creates it
    defined $Dancer2::runner
        or $Dancer2::runner = $self;
}

sub register_application {
    my $self = shift;
    my $app  = shift;

    push @{ $self->apps }, $app;

    # add postponed hooks to our psgi app
    $self->add_postponed_hooks( $app->name, $app->postponed_hooks );
}

sub add_postponed_hooks {
    my $self  = shift;
    my $name  = shift;
    my $hooks = shift;

    # merge postponed hooks
    @{ $self->{'postponed_hooks'}{$name} }{ keys %{$hooks} } = values %{$hooks};
}

# decide what to start
# do we just return a PSGI app
# or do we actually start a development standalone server?
sub start {
    my $self = shift;
    my $app  = $self->psgi_app;

    # we decide whether we return a PSGI coderef
    # or spin a local development PSGI server
    $self->config->{'apphandler'} eq 'PSGI'
        and return $app;

    # FIXME: this should not include the server tokens
    # since those are already added to the server itself
    $self->start_server($app);
}

sub start_server {
    my $self = shift;
    my $app  = shift;

    # does not return
    $self->print_banner;
    $self->server->run($app);
}

sub psgi_app {
    my ($self, $apps) = @_;

    if ( $apps && @{$apps} ) {
        my @found_apps = ();

        foreach my $app_req ( @{$apps} ) {
            if ( is_regexpref($app_req) ) {
                # find it in the apps registry
                push @found_apps,
                    grep +( $_->name =~ $app_req ), @{ $self->apps };
            } elsif ( ref $app_req eq 'Dancer2::Core::App' ) {
                # use it directly
                push @found_apps, $app_req;
            } elsif ( !is_ref($app_req) ) {
                # find it in the apps registry
                push @found_apps,
                    grep +( $_->name eq $app_req ), @{ $self->apps };
            } else {
                croak "Invalid input to psgi_app: $app_req";
            }
        }

        $apps = \@found_apps;
    } else {
        # dispatch over all apps by default
        $apps = $self->apps;
    }

    my $dispatcher = Dancer2::Core::Dispatcher->new( apps => $apps );

    # initialize psgi_apps
    # (calls ->finish on the apps and create their PSGI apps)
    # the dispatcher caches that in the attribute
    # so ->finish isn't actually called again if you run this method
    $dispatcher->apps_psgi;

    return sub {
        my $env = shift;

        # mark it as an old-style dispatching
        $self->{'internal_dispatch'} = 1;

        my $response = $dispatcher->dispatch($env);

        # unmark it
        delete $self->{'internal_dispatch'};

        # cleanup
        delete $self->{'internal_sessions'};

        return $response;
    };
}

sub print_banner {
    my $self = shift;
    my $pid  = $$;

    # we only print the info if we need to
    $self->config->{'startup_info'} or return;

    # bare minimum
    print STDERR ">> Dancer2 v" . Dancer2->VERSION . " server $pid listening "
      . 'on http://'
      . $self->host . ':'
      . $self->port . "\n";

    # all loaded plugins
    foreach my $module ( grep { $_ =~ m{^Dancer2/Plugin/} } keys %INC ) {
        $module =~ s{/}{::}g;     # change / to ::
        $module =~ s{\.pm$}{};    # remove .pm at the end
        my $version = $module->VERSION;

        defined $version or $version = 'no version number defined';
        print STDERR ">> $module ($version)\n";
    }
}

1;
