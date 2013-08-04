# ABSTRACT: Top-layer class to start a dancer app
package Dancer2::Core::Runner;

use Moo;
use Dancer2::Core::Types;
use Dancer2::Core::MIME;
use Carp 'croak';

use Dancer2::FileUtils;
use Dancer2::ModuleLoader;
use File::Basename;
use File::Spec;

with 'Dancer2::Core::Role::Config';

has postponed_hooks => (
    is      => 'rw',
    isa     => HashRef,
    default => sub { {} },
);

# the path to the caller script that is starting the app
# mandatory, because we use that to determine where the appdir is.
has caller => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has server => (
    is      => 'rw',
    isa     => ConsumerOf ['Dancer2::Core::Role::Server'],
    lazy    => 1,
    builder => '_build_server',
);

has mime_type => (
    is      => 'rw',
    isa     => InstanceOf ["Dancer2::Core::MIME"],
    default => sub { Dancer2::Core::MIME->new(); },
);

# when the runner is created, it has to init the server instance
# according to the configuration
sub _build_server {
    my $self         = shift;
    my $server_name  = $self->config->{apphandler};
    my $server_class = "Dancer2::Core::Server::${server_name}";

    my ( $res, $error ) = Dancer2::ModuleLoader->load($server_class);
    $res or croak "Unable to load $server_class : $error";

    return $server_class->new(
        host      => $self->config->{host},
        port      => $self->config->{port},
        is_daemon => $self->config->{is_daemon},
        runner    => $self,
    );
}

# our Config role needs a default_config hash
sub default_config {

    $ENV{PLACK_ENV}
      and $ENV{DANCER_APPHANDLER} = 'PSGI';

    my ($self) = @_;
    {   apphandler   => ( $ENV{DANCER_APPHANDLER}   || 'Standalone' ),
        content_type => ( $ENV{DANCER_CONTENT_TYPE} || 'text/html' ),
        charset      => ( $ENV{DANCER_CHARSET}      || '' ),
        warnings     => ( $ENV{DANCER_WARNINGS}     || 0 ),
        startup_info => ( $ENV{DANCER_STARTUP_INFO} || 1 ),
        traces       => ( $ENV{DANCER_TRACES}       || 0 ),
        logger       => ( $ENV{DANCER_LOGGER}       || 'console' ),
        host         => ( $ENV{DANCER_SERVER}       || '0.0.0.0' ),
        port         => ( $ENV{DANCER_PORT}         || '3000' ),
        is_daemon    => ( $ENV{DANCER_DAEMON}       || 0 ),
        views        => ( $ENV{DANCER_VIEWS}
              || path( $self->config_location, 'views' ) ),
        appdir          => $self->location,
        import_warnings => 1,
    };
}

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

        # if one of them is found, keep that
        if ( ( -d $libdir && -d $bindir ) || ( -f $dancerdir ) ) {
            $subdir_found = 1;
            last;
        }

        $subdir = Dancer2::FileUtils::path( $subdir, '..' );
        last if File::Spec->rel2abs($subdir) eq File::Spec->rootdir;

    }

    my $path = $subdir_found ? $subdir : $location;

    # return if absolute
    File::Spec->file_name_is_absolute($path)
        and return $path;

    # convert relative to absolute
    return File::Spec->rel2abs($path);
}

sub BUILD {
    my $self = shift;

    # this assures any failure in building the location
    # will be encountered as soon as possible
    # while making sure that 'caller' is already available
    $self->location;
}

sub start {
    my ($self) = @_;
    my $server = $self->server;

    $_->finish for @{ $server->apps };

    # update the server config if needed
    my $port      = $self->setting('server_port');
    my $host      = $self->setting('server_host');
    my $is_daemon = $self->setting('server_is_daemon');

    $server->port($port)           if defined $port;
    $server->host($host)           if defined $host;
    $server->is_daemon($is_daemon) if defined $is_daemon;
    $server->start;
}

# Used by 'logger' to get a name from a Runner
sub name {"runner"}

1;

#still exists?
#=method BUILD
#
#The builder initializes the proper server instance (C<Dancer2::Core::Server::*>)
#and sets the C<server> attribute to it.
#
#=method get_environment
#
#Returns the environment. Same as C<< $object->environment >>.

__END__

=head1 DESCRIPTION

Runs Dancer2 app.

Inherits from L<Dancer2::Core::Role::Config>.

=head2 environment

The environment string. The options, in this order, are:

=over 4

=item * C<DANCER_ENVIRONMENT>

=item * C<PLACK_ENV>

=item * C<development>

=back

=attr postponed_hooks

Postponed hooks will be applied at the end, when the hookable objects are 
instantiated, not before.

=attr caller

The path to the caller script that is starting the app.

This is required in order to determine where the appdir is.

=attr server

A read/write attribute to that holds the proper server.

It checks for an object that consumes the L<Dancer2::Core::Role::Server> role.

=attr mime_type

A read/write attribute that holds a L<Dancer2::Core::MIME> object.

=method default_config

It then sets up the default configuration.

=method start

Runs C<finish> (to set everything up) on all of the server's applications. It
then Sets up the current server and starts it by calling its C<start> method.

