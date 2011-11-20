package t::lib::FooPlugin;
use Dancer::Plugin;

register foo_wrap_request => sub {
    my ($self) = @_;
    return $self->request;
},
{ is_global => 0 };

register foo_route => sub {
    my $self = shift;
    $self->get('/foo', sub {'foo'});
};

register_plugin;
1;
