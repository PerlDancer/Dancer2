package Dancer2::Core::Hook;
# ABSTRACT: Manipulate hooks with Dancer2

use Moo;
use Dancer2::Core::Types;
use Carp;

has name => (
    is       => 'rw',
    isa      => Str,
    required => 1,
    coerce   => sub {
        my ($hook_name) = @_;

        # XXX at the moment, we have a filer position named "before_template".
        # this one is renamed "before_template_render", so we need to alias it.
        # maybe we need to deprecate 'before_template' to enforce the use
        # of 'hook before_template_render => sub {}' ?
        $hook_name = 'before_template_render'
          if $hook_name eq 'before_template';
        return $hook_name;
    },
);

has code => (
    is       => 'ro',
    isa      => CodeRef,
    required => 1,
    coerce   => sub {
        my ($hook) = @_;
        sub {
            my $res;
            eval { $res = $hook->(@_) };
            croak "Hook error: $@" if $@;
            return $res;
        };
    },
);

1;

__END__

=head1 SYNOPSIS

  # inside a plugin
  use Dancer2::Core::Hook;
  Dancer2::Core::Hook->register_hooks_name(qw/before_auth after_auth/);

=method register_hook ($hook_name, [$properties], $code)

    hook 'before', {apps => ['main']}, sub {...};

    hook 'before' => sub {...};

Attaches a hook at some point, with a possible list of properties.

Currently supported properties:

=over 4

=item apps

    an array reference containing apps name

=back

=method register_hooks_name

Add a new hook name, so application developers can insert some code at this point.

    package My::Dancer2::Plugin;
    Dancer2::Core::Hook->instance->register_hooks_name(qw/before_auth after_auth/);

=head2 hook_is_registered

Test if a hook with this name has already been registered.

=method execute_hook

Execute a hooks

=method get_hooks_for

Returns the list of coderef registered for a given position

=cut
