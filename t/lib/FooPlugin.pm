package t::lib::FooPlugin;
use Moo::Role;
use Dancer::Plugin;

sub dsl_keywords {
    [
        [ 'foo_route' => 1],
        [ 'foo_wrap_request' => 0],
    ]
}

sub foo_wrap_request {
    my ($self) = @_;
    return $self->request;
}

sub foo_route {
    my $self = shift;
    $self->get('/foo', sub {'foo'});
}

Dancer::Plugin::register_plugin;
1;
