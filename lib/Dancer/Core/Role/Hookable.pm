package Dancer::Core::Role::Hookable;
use Moo::Role;
use Dancer::Moo::Types;
use Carp 'croak';

# Currently the app needs a hook registry
# but I think it might be useful later to be able to 
# compose other classes with this generic facility.
# Like binding hooks to Request objects for instance.
# We'll see...

# The hooks registry 
has hooks => (
    is => 'rw',
    isa => sub { HashRef(@_) },
    default => sub { {} },
);

# This lets you define a list of possible hook names
# for the registry
sub install_hook {
    my ($self, @hook_names) = @_;
    for my $h (@hook_names) {
        croak "Hook '$h' is already registered, please use another name" 
          if $self->has_hook($h);
        $self->{hooks}->{$h} = [];
    }
}

# This binds a coderef to an installed hook if not already
# existing
sub add_hook {
    my ($self, $hook) = @_;
    my $name = $hook->name;
    my $code = $hook->code;

    croak "Hook '$name' must be installed first"
        unless $self->has_hook($name);
    
    push @{ $self->hooks->{$name} }, $code;
}

# Boolean flag to tells if the hook is registered or not
sub has_hook {
    my ($self, $hook_name) = @_;
    return exists $self->hooks->{$hook_name};
}

# Exectue the hook at the given position
sub execute_hooks {
    my ($self, $name, @args) = @_;

    croak "execute_hook needs a hook name"
      if !defined $name || !length($name);

    croak "Hook '$name' does not exist"
      if !$self->has_hook($name);
    
    $_->(@args) for @{ $self->hooks->{$name} };
}

1;
__END__
