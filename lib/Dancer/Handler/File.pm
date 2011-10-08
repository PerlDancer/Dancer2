package Dancer::Handler::File;
use Carp 'croak';
use Moo;
use HTTP::Date;
use Dancer::FileUtils 'path', 'read_file_content';
use Dancer::Core::MIME;
use Dancer::Moo::Types;

with 'Dancer::Core::Role::Handler';
with 'Dancer::Core::Role::StandardResponses';

has mime => (
    is => 'ro',
    isa => sub { ObjectOf('Dancer::Core::MIME', @_) },
    default => sub { Dancer::Core::MIME->new },
);

has encoding => (
    is => 'ro',
    default => sub { 'utf-8' },
);

has public_dir => (
    is => 'ro',
);

has regexp => (
    is => 'ro',
    default => sub { '/**' },
);

sub BUILD {
    my ($self) = @_;

    if (! defined $self->public_dir) {
        my $public =
             $self->app->config->{public}
          || $ENV{DANCER_PUBLIC}
          || path($self->app->location, 'public');

        $self->public_dir($public);
    }
}

sub register {
    my ($self, $app) = @_;

    # don't register the handler if no valid public dir
    return if ! -d $self->public_dir;

    $app->add_route(
        method => $_,
        regexp => $self->regexp,
        code   => $self->code,
    ) for $self->methods;
}

sub methods { ('head', 'get') } 

sub code {
    my ($self) = @_;

    sub {
        my $ctx  = shift;
        my $path = $ctx->request->path_info;

        if ($path =~ /\0/) {
            return $self->response_400($ctx);
        }

        my @tokens = split '/', $path;
        if (grep $_ eq '..', @tokens) {
            return $self->response_403($ctx);
        }

        my $file_path = path($self->public_dir, @tokens);

        if (! -f $file_path) {
            $ctx->response->has_passed(1);
            return;
        }

        if (! -r $file_path) {
            return $self->response_403($ctx);
        }

        my $content = read_file_content($file_path);
        my $content_type = $self->mime->for_file($file_path) || 'text/plain';

        if ($content_type =~ m!^text/!) {
            $content_type .= "; charset=" . ($self->encoding || "utf-8");
        }

        my @stat = stat $file_path;
        $ctx->response->push_header('Content-Type', $content_type);
        $ctx->response->push_header('Content-Length', $stat[7]);
        $ctx->response->push_header('Last-Modified', HTTP::Date::time2str($stat[9]));

        return ($ctx->request->method eq 'GET') ? $content : '';
    };
}

1;
