use strict;
use warnings;

package Dancer2::Bundled::App::Cmd::Simple;
$Dancer2::Bundled::App::Cmd::Simple::VERSION = '0.331';
use Dancer2::Bundled::App::Cmd::Command;
BEGIN { our @ISA = 'Dancer2::Bundled::App::Cmd::Command' }

# ABSTRACT: a helper for building one-command Dancer2::Bundled::App::Cmd applications

use Dancer2::Bundled::App::Cmd;
use Sub::Install;

#pod =head1 SYNOPSIS
#pod
#pod in F<simplecmd>:
#pod
#pod   use YourDancer2::Bundled::App::Cmd;
#pod   Your::Cmd->run;
#pod
#pod in F<YourApp/Cmd.pm>:
#pod
#pod   package YourDancer2::Bundled::App::Cmd;
#pod   use base qw(Dancer2::Bundled::App::Cmd::Simple);
#pod
#pod   sub opt_spec {
#pod     return (
#pod       [ "blortex|X",  "use the blortex algorithm" ],
#pod       [ "recheck|r",  "recheck all results"       ],
#pod     );
#pod   }
#pod
#pod   sub validate_args {
#pod     my ($self, $opt, $args) = @_;
#pod
#pod     # no args allowed but options!
#pod     $self->usage_error("No args allowed") if @$args;
#pod   }
#pod
#pod   sub execute {
#pod     my ($self, $opt, $args) = @_;
#pod
#pod     my $result = $opt->{blortex} ? blortex() : blort();
#pod
#pod     recheck($result) if $opt->{recheck};
#pod
#pod     print $result;
#pod   }
#pod
#pod and, finally, at the command line:
#pod
#pod   knight!rjbs$ simplecmd --recheck
#pod
#pod   All blorts successful.
#pod
#pod =head1 SUBCLASSING
#pod
#pod When writing a subclass of Dancer2::Bundled::App::Cmd:Simple, there are only a few methods that
#pod you might want to implement.  They behave just like the same-named methods in
#pod Dancer2::Bundled::App::Cmd.
#pod
#pod =head2 opt_spec
#pod
#pod This method should be overridden to provide option specifications.  (This is
#pod list of arguments passed to C<describe_options> from Getopt::Long::Descriptive,
#pod after the first.)
#pod
#pod If not overridden, it returns an empty list.
#pod
#pod =head2 usage_desc
#pod
#pod This method should be overridden to provide the top level usage line.
#pod It's a one-line summary of how the command is to be invoked, and
#pod should be given in the format used for the C<$usage_desc> parameter to
#pod C<describe_options> in Getopt::Long::Descriptive.
#pod
#pod If not overriden, it returns something that prints out like:
#pod
#pod   yourapp [-?h] [long options...]
#pod
#pod =head2 validate_args
#pod
#pod   $cmd->validate_args(\%opt, \@args);
#pod
#pod This method is passed a hashref of command line options (as processed by
#pod Getopt::Long::Descriptive) and an arrayref of leftover arguments.  It may throw
#pod an exception (preferably by calling C<usage_error>) if they are invalid, or it
#pod may do nothing to allow processing to continue.
#pod
#pod =head2 execute
#pod
#pod   Your::Dancer2::Bundled::App::Cmd::Simple->execute(\%opt, \@args);
#pod
#pod This method does whatever it is the command should do!  It is passed a hash
#pod reference of the parsed command-line options and an array reference of left
#pod over arguments.
#pod
#pod =cut

# The idea here is that the user will someday replace "Simple" in his ISA with
# "Command" and then write a standard Dancer2::Bundled::App::Cmd package.  To make that possible,
# we produce a behind-the-scenes Dancer2::Bundled::App::Cmd object when the user says 'use
# MyApp::Simple' and redirect MyApp::Simple->run to that.
my $i;
BEGIN { $i = 0 }

sub import {
  my ($class) = @_;
  return if $class eq __PACKAGE__;

  # This signals that something has already set the target up.
  return $class if $class->_cmd_pkg;

  my $core_execute = Dancer2::Bundled::App::Cmd::Command->can('execute');
  my $our_execute  = $class->can('execute');
  Carp::confess(
    "Dancer2::Bundled::App::Cmd::Simple subclasses must implement ->execute, not ->run"
  ) unless $our_execute and $our_execute != $core_execute;

  # I doubt the $i will ever be needed, but let's start paranoid.
  my $generated_name = join('::', $class, '_App_Cmd', $i++);

  {
    no strict 'refs';
    *{$generated_name . '::ISA'} = [ 'Dancer2::Bundled::App::Cmd' ];
  }

  Sub::Install::install_sub({
    into => $class,
    as   => '_cmd_pkg',
    code => sub { $generated_name },
  });

  Sub::Install::install_sub({
      into => $class,
      as => 'command_names',
      code => sub { 'only' },
  });

  Sub::Install::install_sub({
    into => $generated_name,
    as   => '_plugins',
    code => sub { $class },
  });

  Sub::Install::install_sub({
    into => $generated_name,
    as   => 'default_command',
    code => sub { 'only' },
  });

  Sub::Install::install_sub({
    into => $generated_name,
    as   => '_cmd_from_args',
    code => sub {
      my ($self, $args) = @_;
      if (defined(my $command = $args->[0])) {
        my $plugin = $self->plugin_for($command);
        # If help was requested, show the help for the command, not the
        # main help. Because the main help would talk about subcommands,
        # and a "Simple" app has no subcommands.
        if ($plugin and $plugin eq $self->plugin_for("help")) {
          return ($command, [ $self->default_command ]);
        }
        # Any other value for "command" isn't really a command at all --
        # it's the first argument. So call the default command instead.
      }
      return ($self->default_command, $args);
    },
  });

  Sub::Install::install_sub({
    into => $class,
    as   => 'run',
    code => sub {
      $generated_name->new({
        no_help_plugin     => 0,
        no_commands_plugin => 1,
      })->run(@_);
    }
  });

  return $class;
}

sub usage_desc {
  return "%c %o"
}

sub _cmd_pkg { }

#pod =head1 WARNINGS
#pod
#pod B<This should be considered experimental!>  Although it is probably not going
#pod to change much, don't build your business model around it yet, okay?
#pod
#pod Dancer2::Bundled::App::Cmd::Simple is not rich in black magic, but it does do some somewhat
#pod gnarly things to make an Dancer2::Bundled::App::Cmd::Simple look as much like an
#pod Dancer2::Bundled::App::Cmd::Command as possible.  This means that you can't deviate too much from
#pod the sort of thing shown in the synopsis as you might like.  If you're doing
#pod something other than writing a fairly simple command, and you want to screw
#pod around with the Dancer2::Bundled::App::Cmd-iness of your program, Simple might not be the best
#pod choice.
#pod
#pod B<One specific warning...>  if you are writing a program with the
#pod Dancer2::Bundled::App::Cmd::Simple class embedded in it, you B<must> call import on the class.
#pod That's how things work.  You can just do this:
#pod
#pod   YourDancer2::Bundled::App::Cmd->import->run;
#pod
#pod =cut

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Bundled::App::Cmd::Simple - a helper for building one-command Dancer2::Bundled::App::Cmd applications

=head1 VERSION

version 0.331

=head1 SYNOPSIS

in F<simplecmd>:

  use YourDancer2::Bundled::App::Cmd;
  Your::Cmd->run;

in F<YourApp/Cmd.pm>:

  package YourDancer2::Bundled::App::Cmd;
  use base qw(Dancer2::Bundled::App::Cmd::Simple);

  sub opt_spec {
    return (
      [ "blortex|X",  "use the blortex algorithm" ],
      [ "recheck|r",  "recheck all results"       ],
    );
  }

  sub validate_args {
    my ($self, $opt, $args) = @_;

    # no args allowed but options!
    $self->usage_error("No args allowed") if @$args;
  }

  sub execute {
    my ($self, $opt, $args) = @_;

    my $result = $opt->{blortex} ? blortex() : blort();

    recheck($result) if $opt->{recheck};

    print $result;
  }

and, finally, at the command line:

  knight!rjbs$ simplecmd --recheck

  All blorts successful.

=head1 SUBCLASSING

When writing a subclass of Dancer2::Bundled::App::Cmd:Simple, there are only a few methods that
you might want to implement.  They behave just like the same-named methods in
Dancer2::Bundled::App::Cmd.

=head2 opt_spec

This method should be overridden to provide option specifications.  (This is
list of arguments passed to C<describe_options> from Getopt::Long::Descriptive,
after the first.)

If not overridden, it returns an empty list.

=head2 usage_desc

This method should be overridden to provide the top level usage line.
It's a one-line summary of how the command is to be invoked, and
should be given in the format used for the C<$usage_desc> parameter to
C<describe_options> in Getopt::Long::Descriptive.

If not overriden, it returns something that prints out like:

  yourapp [-?h] [long options...]

=head2 validate_args

  $cmd->validate_args(\%opt, \@args);

This method is passed a hashref of command line options (as processed by
Getopt::Long::Descriptive) and an arrayref of leftover arguments.  It may throw
an exception (preferably by calling C<usage_error>) if they are invalid, or it
may do nothing to allow processing to continue.

=head2 execute

  Your::Dancer2::Bundled::App::Cmd::Simple->execute(\%opt, \@args);

This method does whatever it is the command should do!  It is passed a hash
reference of the parsed command-line options and an array reference of left
over arguments.

=head1 WARNINGS

B<This should be considered experimental!>  Although it is probably not going
to change much, don't build your business model around it yet, okay?

Dancer2::Bundled::App::Cmd::Simple is not rich in black magic, but it does do some somewhat
gnarly things to make an Dancer2::Bundled::App::Cmd::Simple look as much like an
Dancer2::Bundled::App::Cmd::Command as possible.  This means that you can't deviate too much from
the sort of thing shown in the synopsis as you might like.  If you're doing
something other than writing a fairly simple command, and you want to screw
around with the Dancer2::Bundled::App::Cmd-iness of your program, Simple might not be the best
choice.

B<One specific warning...>  if you are writing a program with the
Dancer2::Bundled::App::Cmd::Simple class embedded in it, you B<must> call import on the class.
That's how things work.  You can just do this:

  YourDancer2::Bundled::App::Cmd->import->run;

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
