package Dancer2::Handler::File;
# ABSTRACT: class for handling file content rendering

use Carp 'croak';
use Moo;
use HTTP::Date;
use Dancer2::FileUtils 'path';
use Dancer2::Core::MIME;
use Dancer2::Core::Types;
use Path::Tiny ();
use File::Spec;

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

sub register {
    my ( $self, $app ) = @_;

    # don't register the handler if no valid public dir
    return if !-d $self->public_dir;

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

        my $file_path = $self->merge_paths( $path, $self->public_dir );
        return $self->standard_response( $app, 403 ) if !defined $file_path;

        if ( !-f $file_path ) {
            $app->response->has_passed(1);
            return;
        }

        if ( !-r $file_path ) {
            return $self->standard_response( $app, 403 );
        }

        # Now we are sure we can render the file...
        $self->execute_hook( 'handler.file.before_render', $file_path );

        # Read file content as bytes
        my $content = Path::Tiny::path($file_path)->slurp_raw;

        # Assume m/^text/ mime types are correctly encoded
        my $content_type = $self->mime->for_file($file_path) || 'text/plain';
        if ( $content_type =~ m!^text/! ) {
            $content_type .= "; charset=" . ( $self->encoding || "utf-8" );
        }

        my @stat = stat $file_path;

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

sub merge_paths {
    my ( undef, $path, $public_dir ) = @_;

    my ( $volume, $dirs, $file ) = File::Spec->splitpath( $path );
    my @tokens = File::Spec->splitdir( "$dirs$file" );
    my $updir = File::Spec->updir;
    return if grep $_ eq $updir, @tokens;

    my ( $pub_vol, $pub_dirs, $pub_file ) = File::Spec->splitpath( $public_dir );
    my @pub_tokens = File::Spec->splitdir( "$pub_dirs$pub_file" );
    return if length $volume and length $pub_vol and $volume ne $pub_vol;

    my @final_vol = ( length $pub_vol ? $pub_vol : length $volume ? $volume : () );
    my @file_path = ( @final_vol, @pub_tokens, @tokens );
    my $file_path = path( @file_path );
    return $file_path;
}

1;
