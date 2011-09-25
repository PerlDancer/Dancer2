package Dancer::Handler::File;
use Carp 'croak';
use Moo;
use Dancer::FileUtils 'path', 'read_file_content';
use Dancer::Core::MIME;
use Dancer::Moo::Types;

has mime => (
    is => 'ro',
    isa => sub { ObjectOf('Dancer::Core::MIME', @_) },
    default => sub { Dancer::Core::MIME->new },
);

has public_dir => (
    is => 'ro',
    isa => sub { -d $_[0] or croak "Not a regular location: $_[0]" },
    default => sub { File::Spec->rel2abs('.') },
);

has regexp => (
    is => 'ro',
    default => sub { qr{.*} },
);

sub methods { ('head', 'get') } 

sub code {
    my ($self) = @_;

    sub {
        my $ctx  = shift;
        my $path = $ctx->request->path_info;

        my @tokens = split '/', $path;
        my $file_path = path($self->public_dir, @tokens);

        if (! -r $file_path || ! -f $file_path) {
            $ctx->response->has_passed(1);
            return;
        }

        my $content = read_file_content($file_path);
        $ctx->response->push_header('Content-Type', $self->mime->for_file($file_path));
        $ctx->response->push_header('Content-Length', length($content));

        return ($ctx->request->method eq 'GET') ? $content : '';
    };
}

1;
