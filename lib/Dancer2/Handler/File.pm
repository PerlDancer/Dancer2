package Dancer2::Handler::File;
# ABSTRACT: class for handling file content rendering

use Carp 'croak';
use Moo;
use HTTP::Date;
use Dancer2::Core::MIME;
use Dancer2::Core::Types;
use Path::Tiny ();

with qw<
    Dancer2::Core::Role::Handler
    Dancer2::Core::Role::StandardResponses
    Dancer2::Core::Role::Hookable
>;

sub hook_aliases {
    {
        before_file_render => 'handler.file.before_render',
        after_file_render  => 'handler.file.after_render',
    }
}

sub supported_hooks { values %{ shift->hook_aliases } }

has mime => (
    is      => 'ro',
    isa     => InstanceOf ['Dancer2::Core::MIME'],
    default => sub { Dancer2::Core::MIME->new },
);

has encoding => (
    is      => 'ro',
    default => sub {'utf-8'},
);

has public_dir => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_public_dir',
);

has _public_dir_path => (
    is       => 'ro',
    lazy     => 1,
    builder  => '_build_public_dir_path',
    init_arg => undef,
);

has regexp => (
    is      => 'ro',
    default => sub {'/**'},
);

sub _build_public_dir {
    my $self = shift;
    return $self->app->config->{public_dir}
        || $ENV{DANCER_PUBLIC}
        || Path::Tiny::path( $self->app->location, 'public' )->stringify;
}

sub _build_public_dir_path {
    my $self = shift;
    return Path::Tiny::path( $self->public_dir );
}

sub register {
    my ( $self, $app ) = @_;

    # don't register the handler if no valid public dir
    return if !$self->_public_dir_path->is_dir;

    $app->add_route(
        method => $_,
        regexp => $self->regexp,
        code   => $self->code( $app->prefix ),
    ) for $self->methods;
}

sub methods { ( 'head', 'get' ) }

sub code {
    my ( $self, $prefix ) = @_;

    sub {
        my $app    = shift;
        my $prefix = shift;
        my $path   = $app->request->path_info;

        if ( $path =~ /\0/ ) {
            return $self->standard_response( $app, 400 );
        }

        if ( $prefix && $prefix ne '/' ) {
            $path =~ s/^\Q$prefix\E//;
        }

        my $file_path = Path::Tiny::path( $self->_public_dir_path, $path );
        my $file_path_str = $file_path->stringify;

        if ( !-f $file_path_str ) {
            $app->response->has_passed(1);
            return;
        }

        # Path::Tiny does not collapse '../' segments, so the joined path
        # above may still point outside public_dir even though it is a
        # readable file (F4). Resolve it and refuse anything that escapes,
        # the same containment check send_file uses at
        # Dancer2/Core/App.pm:1180-1182. This is only safe to call now: the
        # -f check above guarantees the file (and so every directory in its
        # path) exists, so realpath cannot die here.
        $file_path      = $file_path->realpath;
        $file_path_str  = $file_path->stringify;

        if ( !$self->_public_dir_path->realpath->subsumes($file_path) ) {
            return $self->standard_response( $app, 403 );
        }

        if ( !-r $file_path_str ) {
            return $self->standard_response( $app, 403 );
        }

        # Now we are sure we can render the file...
        $self->execute_hook( 'handler.file.before_render', $file_path_str );

        # Read file content as bytes
        my $content = $file_path->slurp_raw;

        # Assume m/^text/ mime types are correctly encoded
        my $content_type = $self->mime->for_file($file_path_str) || 'text/plain';
        if ( $content_type =~ m!^text/! ) {
            $content_type .= "; charset=" . ( $self->encoding || "utf-8" );
        }

        my @stat = stat $file_path_str;

        $app->response->header('Content-Type')
          or $app->response->header( 'Content-Type', $content_type );

        $app->response->header('Content-Length')
          or $app->response->header( 'Content-Length', $stat[7] );

        $app->response->header('Last-Modified')
          or $app->response->header(
            'Last-Modified',
            HTTP::Date::time2str( $stat[9] )
          );

        $app->response->content($content);
        $app->response->is_encoded(1);    # bytes are already encoded
        $self->execute_hook( 'handler.file.after_render', $app->response );
        return ( $app->request->method eq 'GET' ) ? $content : '';
    };
}

1;
