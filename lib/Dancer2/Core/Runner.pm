package Dancer2::Core::Runner;
# ABSTRACT: Top-layer class to start a dancer app

use Moo;
use Dancer2::Core::MIME;
use Dancer2::Core::Types;
use Dancer2::Core::Dispatcher;
use HTTP::Server::PSGI;
use Plack::Builder qw();

with 'Dancer2::Core::Role::ConfigReader';

# the path to the caller script that is starting the app
# mandatory, because we use that to determine where the appdir is.
has caller => (
    is       => 'ro',
    isa      => Str,
    required => 1,
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

has dispatcher => (
    is      => 'ro',
    isa     => InstanceOf ['Dancer2::Core::Dispatcher'],
    lazy    => 1,
    builder => '_build_dispatcher',
);

has postponed_hooks => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { +{} },
);

# FIXME: this should be in the configuration
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

sub _build_dispatcher {
    my $self = shift;
    return Dancer2::Core::Dispatcher->new( apps => $self->apps );
}

sub _build_server {
    my $self = shift;

    HTTP::Server::PSGI->new(
        host            => $self->host,
        port            => $self->port,
        timeout         => $self->timeout,
        server_software => "Perl Dancer2 $Dancer2::VERSION",
    );
}

# FIXME: i hate you most of all
sub _build_location {
    my $self   = shift;
    my $script = $self->caller;

    # default to the dir that contains the script...
    my $location = Dancer2::FileUtils::dirname($script);

    #we try to find bin and lib
    my $subdir       = $location;
    my $subdir_found = 0;

    #maximum of 10 iterations, to prevent infinite loop
    for ( 1 .. 10 ) {

        #try to find libdir and bindir to determine the root of dancer app
        my $libdir = Dancer2::FileUtils::path( $subdir, 'lib' );
        my $bindir = Dancer2::FileUtils::path( $subdir, 'bin' );

        #try to find .dancer_app file to determine the root of dancer app
        my $dancerdir = Dancer2::FileUtils::path( $subdir, '.dancer' );

        # if one of them is found, keep that; but skip ./blib since both lib and bin exist
        # under it, but views and public do not.
        if ( ( $subdir !~ m!/blib/?$! && -d $libdir && -d $bindir ) || ( -f $dancerdir ) ) {
            $subdir_found = 1;
            last;
        }

        $subdir = Dancer2::FileUtils::path( $subdir, '..' ) || '.';
        last if File::Spec->rel2abs($subdir) eq File::Spec->rootdir;

    }

    my $path = $subdir_found ? $subdir : $location;

    # return if absolute
    File::Spec->file_name_is_absolute($path)
        and return $path;

    # convert relative to absolute
    return File::Spec->rel2abs($path);
}

sub _build_default_config {
    my $self = shift;

    $ENV{PLACK_ENV}
      and $ENV{DANCER_APPHANDLER} = 'PSGI';

    return {
        apphandler   => ( $ENV{DANCER_APPHANDLER}   || 'Standalone' ),
        content_type => ( $ENV{DANCER_CONTENT_TYPE} || 'text/html' ),
        charset      => ( $ENV{DANCER_CHARSET}      || '' ),
        warnings     => ( $ENV{DANCER_WARNINGS}     || 0 ),
        startup_info => ( $ENV{DANCER_STARTUP_INFO} || 1 ),
        traces       => ( $ENV{DANCER_TRACES}       || 0 ),
        logger       => ( $ENV{DANCER_LOGGER}       || 'console' ),
        host         => ( $ENV{DANCER_SERVER}       || '0.0.0.0' ),
        port         => ( $ENV{DANCER_PORT}         || '3000' ),
        views        => ( $ENV{DANCER_VIEWS}
              || path( $self->config_location, 'views' ) ),
        appdir        => $self->location,
    };
}

sub BUILD {
    my $self = shift;

    # this assures any failure in building the location
    # will be encountered as soon as possible
    # while making sure that 'caller' is already available
    $self->location;

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
    $self->add_postponed_hooks( $app->postponed_hooks );
}

sub add_postponed_hooks {
    my $self  = shift;
    my $hooks = shift;

    # merge postponed hooks
    @{ $self->{'postponed_hooks'} }{ keys %{$hooks} } = values %{$hooks};
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
    my $self   = shift;
    my $server = $self->server;

    foreach my $app ( @{ $self->apps } ) {
        $app->finish;
    }

    # eval entire request to catch any internal errors
    my $psgi = sub {
        my $env = shift;
        my $response;

        # pre-request sanity check
        my $method = uc $env->{'REQUEST_METHOD'};
        $Dancer2::Core::Types::supported_http_methods{$method}
            or return [
                405,
                [ 'Content-Type' => 'text/plain' ],
                [ "Method Not Allowed\n\n$method is not supported." ]
            ];

        eval {
            $response = $self->dispatcher->dispatch($env)->to_psgi;
            1;
        } or do {
            return [
                500,
                [ 'Content-Type' => 'text/plain' ],
                [ "Internal Server Error\n\n$@"  ],
            ];
        };

        return $response;
    };

    my $builder = Plack::Builder->new;
    $builder->add_middleware('Head');
    return $builder->wrap($psgi);
}

sub print_banner {
    my $self = shift;
    my $pid  = $$;

    # we only print the info if we need to
    # FIXME: go to the configuration
    #Dancer2->runner->config->{'startup_info'} or return;

    # bare minimum
    print STDERR ">> Dancer2 v$Dancer2::VERSION server $pid listening "
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

