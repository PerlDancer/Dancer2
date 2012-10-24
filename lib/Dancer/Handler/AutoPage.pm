# ABSTRACT: TODO

package Dancer::Handler::AutoPage;
use Moo;
use Carp 'croak';
use Dancer::Core::Types;

with 'Dancer::Core::Role::Handler';
with 'Dancer::Core::Role::StandardResponses';

sub register {
    my ($self, $app) = @_;

    return unless $app->config->{auto_page};

    $app->add_route(
        method => $_,
        regexp => $self->regexp,
        code   => $self->code,
    ) for $self->methods;
}

sub code {
    sub {
        my $ctx = shift;

        my $template = $ctx->app->config->{template};
        if (! defined $template) {
            $ctx->response->has_passed(1);
            return;
        }

        my $page = $ctx->request->params->{'page'};
        my $view_path = $template->view($page);
        if (! -f $view_path) {
            $ctx->response->has_passed(1);
            return;
        }

        my $ct = $template->process($page);
        $ctx->response->header('Content-Length', length($ct));
        return ($ctx->request->method eq 'GET') ? $ct : '';
    };
}

sub regexp { '/:page' }

sub methods { qw(head get) }

1;
