package Dancer::Core::Role::Hookable;
use Moo::Role;
use Dancer::Moo::Types;
use Carp 'croak';

requires 'supported_hooks';

# The hooks registry 
has hooks => (
    is => 'rw',
    isa => sub { HashRef(@_) },
    builder => '_build_hooks',
    lazy => 1,
);

sub BUILD { }

# after a hookable object is built, we go over its postponed hooks and register
# them if any.
after BUILD => sub {
    my ($self, $args) = @_;
    $self->_add_postponed_hooks($args) 
        if defined $args->{postponed_hooks};
};

sub _add_postponed_hooks {
    my ( $self, $args ) = @_;
    #Dancer::core_debug("building $self with postponed hooks: ", $postponed_hooks);

    my $postponed_hooks = $args->{postponed_hooks};

    # find the internal name of the hooks, from the caller name
    my $caller = ref($self);
    my ( $dancer, $h_type, $h_name, @rest ) = map { lc } split /::/, $caller;
    $h_name = $rest[0] if $h_name eq 'Role';
    if ( $h_type =~ /(template|logger|serializer|session)/ ) {
        $h_name = $h_type;
        $h_type = 'engine';
    }

    #Dancer::core_debug("looking for hooks for $h_type/$h_name");
    # keep only the hooks we want
    $postponed_hooks = $postponed_hooks->{$h_type}{$h_name};
    return unless defined $postponed_hooks;

    foreach my $name ( keys %{$postponed_hooks} ) {
        my $hook   = $postponed_hooks->{$name}{hook};
        my $caller = $postponed_hooks->{$name}{caller};

        $self->has_hook($name)
          or croak "$h_name $h_type does not support the hook `$name'.\n"
          . join( ", ", @{$caller} );

        $self->add_hook($hook);
    }
}

# mst++ for the hint
sub _build_hooks {
    my ($self) = @_;
    my %hooks = map +($_ => []), $self->supported_hooks;
    return \%hooks;
}

# This binds a coderef to an installed hook if not already
# existing
sub add_hook {
    my ($self, $hook) = @_;
    my $name = $hook->name;
    my $code = $hook->code;

    croak "Unsupported hook '$name'"
        unless $self->has_hook($name);
    
    push @{ $self->hooks->{$name} }, $code;
}

# allows the caller to replace the current list of hooks at the given position
# this is useful if the object where this role is composed wants to compile the
# hooks.
sub replace_hooks {
    my ($self, $position, $hooks) = @_;

    croak "Hook '$position' must be installed first"
        unless $self->has_hook($position);
    
    $self->hooks->{$position} = $hooks;
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
