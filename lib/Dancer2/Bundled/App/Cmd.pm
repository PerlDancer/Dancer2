use strict;
use warnings;
use 5.006;

package Dancer2::Bundled::App::Cmd;
$Dancer2::Bundled::App::Cmd::VERSION = '0.331';
use Dancer2::Bundled::App::Cmd::ArgProcessor;
BEGIN { our @ISA = 'Dancer2::Bundled::App::Cmd::ArgProcessor' };
# ABSTRACT: write command line apps with less suffering

use File::Basename ();
use Module::Pluggable::Object ();
use Class::Load ();

use Sub::Exporter -setup => {
  collectors => {
    -ignore  => \'_setup_ignore',
    -command => \'_setup_command',
    -run     => sub {
      warn "using -run to run your command is deprecated\n";
      $_[1]->{class}->run; 1
    },
  },
};

sub _setup_command {
  my ($self, $val, $data) = @_;
  my $into = $data->{into};

  Carp::confess "Dancer2::Bundled::App::Cmd -command setup requested for already-setup class"
    if $into->isa('Dancer2::Bundled::App::Cmd::Command');

  {
    my $base = $self->_default_command_base;
    Class::Load::load_class($base);
    no strict 'refs';
    push @{"$into\::ISA"}, $base;
  }

  $self->_register_command($into);

  for my $plugin ($self->_plugin_plugins) {
    $plugin->import_from_plugin({ into => $into });
  }

  1;
}

sub _setup_ignore {
  my ($self, $val, $data ) = @_;
  my $into = $data->{into};

  Carp::confess "Dancer2::Bundled::App::Cmd -ignore setup requested for already-setup class"
    if $into->isa('Dancer2::Bundled::App::Cmd::Command');

  $self->_register_ignore($into);

  1;
}

sub _plugin_plugins { return }

#pod =head1 SYNOPSIS
#pod
#pod in F<yourcmd>:
#pod
#pod   use YourApp;
#pod   YourApp->run;
#pod
#pod in F<YourApp.pm>:
#pod
#pod   package YourApp;
#pod   use Dancer2::Bundled::App::Cmd::Setup -app;
#pod   1;
#pod
#pod in F<YourApp/Command/blort.pm>:
#pod
#pod   package YourApp::Command::blort;
#pod   use YourApp -command;
#pod   use strict; use warnings;
#pod
#pod   sub abstract { "blortex algorithm" }
#pod
#pod   sub description { "Long description on blortex algorithm" }
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
#pod   knight!rjbs$ yourcmd blort --recheck
#pod
#pod   All blorts successful.
#pod
#pod =head1 DESCRIPTION
#pod
#pod Dancer2::Bundled::App::Cmd is intended to make it easy to write complex command-line applications
#pod without having to think about most of the annoying things usually involved.
#pod
#pod For information on how to start using Dancer2::Bundled::App::Cmd, see L<Dancer2::Bundled::App::Cmd::Tutorial>.
#pod
#pod =method new
#pod
#pod   my $cmd = Dancer2::Bundled::App::Cmd->new(\%arg);
#pod
#pod This method returns a new Dancer2::Bundled::App::Cmd object.  During initialization, command
#pod plugins will be loaded.
#pod
#pod Valid arguments are:
#pod
#pod   no_commands_plugin - if true, the command list plugin is not added
#pod
#pod   no_help_plugin     - if true, the help plugin is not added
#pod
#pod   no_version_plugin  - if true, the version plugin is not added
#pod
#pod   show_version_cmd -   if true, the version command will be shown in the
#pod                        command list
#pod
#pod   plugin_search_path - The path to search for commands in. Defaults to
#pod                        results of plugin_search_path method
#pod
#pod If C<no_commands_plugin> is not given, L<Dancer2::Bundled::App::Cmd::Command::commands> will be
#pod required, and it will be registered to handle all of its command names not
#pod handled by other plugins.
#pod
#pod If C<no_help_plugin> is not given, L<Dancer2::Bundled::App::Cmd::Command::help> will be required,
#pod and it will be registered to handle all of its command names not handled by
#pod other plugins. B<Note:> "help" is the default command, so if you do not load
#pod the default help plugin, you should provide your own or override the
#pod C<default_command> method.
#pod
#pod If C<no_version_plugin> is not given, L<Dancer2::Bundled::App::Cmd::Command::version> will be
#pod required to show the application's version with command C<--version>. By
#pod default, the version command is not included in the command list. Pass
#pod C<show_version_cmd> to include the version command in the list.
#pod
#pod =cut

sub new {
  my ($class, $arg) = @_;

  my $arg0 = $0;
  my $base = File::Basename::basename $arg0;

  my $self = {
    command      => $class->_command($arg),
    arg0         => $base,
    full_arg0    => $arg0,
    show_version => $arg->{show_version_cmd} || 0,
  };

  bless $self => $class;
}

# effectively, returns the command-to-plugin mapping guts of a Cmd
# if called on a class or on a Cmd with no mapping, construct a new hashref
# suitable for use as the object's mapping
sub _command {
  my ($self, $arg) = @_;
  return $self->{command} if ref $self and $self->{command};

  # TODO _default_command_base can be wrong if people are not using
  # ::Setup and have no ::Command :(
  #
  #  my $want_isa = $self->_default_command_base;
  # -- kentnl, 2010-12
  my $want_isa = 'Dancer2::Bundled::App::Cmd::Command';

  my %plugin;
  for my $plugin ($self->_plugins) {

    Class::Load::load_class($plugin);

    # relies on either the plugin itself registering as ignored
    # during compile ( use MyDancer2::Bundled::App::Cmd -ignore )
    # or being explicitly registered elsewhere ( blacklisted )
    # via $app_cmd->_register_ignore( $class )
    #  -- kentnl, 2011-09
    next if $self->should_ignore( $plugin );

    die "$plugin is not a " . $want_isa
      unless $plugin->isa($want_isa);

    next unless $plugin->can("command_names");

    foreach my $command (map { lc } $plugin->command_names) {
      die "two plugins for command $command: $plugin and $plugin{$command}\n"
        if exists $plugin{$command};

      $plugin{$command} = $plugin;
    }
  }

  $self->_load_default_plugin($_, $arg, \%plugin) for qw(commands help version);

  if ($self->allow_any_unambiguous_abbrev) {
    # add abbreviations to list of authorized commands
    require Text::Abbrev;
    my %abbrev = Text::Abbrev::abbrev( keys %plugin );
    @plugin{ keys %abbrev } = @plugin{ values %abbrev };
  }

  return \%plugin;
}

# ->_plugins won't be called more than once on any given Dancer2::Bundled::App::Cmd, but since
# finding plugins can be a bit expensive, we'll do a lousy cache here.
# -- rjbs, 2007-10-09
my %plugins_for;
sub _plugins {
  my ($self) = @_;
  my $class = ref $self || $self;

  return @{ $plugins_for{$class} } if $plugins_for{$class};

  my $finder = Module::Pluggable::Object->new(
    search_path => $self->plugin_search_path,
    $self->_module_pluggable_options,
  );

  my @plugins = $finder->plugins;
  $plugins_for{$class} = \@plugins;

  return @plugins;
}

sub _register_command {
  my ($self, $cmd_class) = @_;
  $self->_plugins;

  my $class = ref $self || $self;
  push @{ $plugins_for{ $class } }, $cmd_class
    unless grep { $_ eq $cmd_class } @{ $plugins_for{ $class } };
}

my %ignored_for;

sub should_ignore {
  my ( $self , $cmd_class ) = @_;
  my $class = ref $self || $self;
  for ( @{ $ignored_for{ $class } } ) {
    return 1 if $_ eq $cmd_class;
  }
  return;
}

sub _register_ignore {
  my ($self, $cmd_class) = @_;
  my $class = ref $self || $self;
  push @{ $ignored_for{ $class } }, $cmd_class
    unless grep { $_ eq $cmd_class } @{ $ignored_for{ $class } };
}

sub _module_pluggable_options {
  # my ($self) = @_; # no point in creating these ops, just to toss $self
  return;
}

# load one of the stock plugins, unless requested to squash; unlike normal
# plugin loading, command-to-plugin mapping conflicts are silently ignored
sub _load_default_plugin {
  my ($self, $plugin_name, $arg, $plugin_href) = @_;
  unless ($arg->{"no_$plugin_name\_plugin"}) {
    my $plugin = "Dancer2::Bundled::App::Cmd::Command::$plugin_name";
    Class::Load::load_class($plugin);
    for my $command (map { lc } $plugin->command_names) {
      $plugin_href->{$command} ||= $plugin;
    }
  }
}

#pod =method run
#pod
#pod   $cmd->run;
#pod
#pod This method runs the application.  If called the class, it will instantiate a
#pod new Dancer2::Bundled::App::Cmd object to run.
#pod
#pod It determines the requested command (generally by consuming the first
#pod command-line argument), finds the plugin to handle that command, parses the
#pod remaining arguments according to that plugin's rules, and runs the plugin.
#pod
#pod It passes the contents of the global argument array (C<@ARGV>) to
#pod L</C<prepare_command>>, but C<@ARGV> is not altered by running an Dancer2::Bundled::App::Cmd.
#pod
#pod =cut

sub run {
  my ($self) = @_;

  # We should probably use Class::Default.
  $self = $self->new unless ref $self;

  # prepare the command we're going to run...
  my @argv = $self->prepare_args();
  my ($cmd, $opt, @args) = $self->prepare_command(@argv);

  # ...and then run it
  $self->execute_command($cmd, $opt, @args);
}

#pod =method prepare_args
#pod
#pod Normally Dancer2::Bundled::App::Cmd uses C<@ARGV> for its commandline arguments. You can override
#pod this method to change that behavior for testing or otherwise.
#pod
#pod =cut

sub prepare_args {
  my ($self) = @_;
  return scalar(@ARGV)
    ? (@ARGV)
    : (@{$self->default_args});
}

#pod =method default_args
#pod
#pod If C<L</prepare_args>> is not changed and there are no arguments in C<@ARGV>,
#pod this method is called and should return an arrayref to be used as the arguments
#pod to the program.  By default, it returns an empty arrayref.
#pod
#pod =cut

use constant default_args => [];

#pod =method abstract 
#pod
#pod    sub abstract { "command description" }
#pod
#pod Defines the command abstract: a short description that will be printed in the
#pod main command options list.
#pod
#pod =method description
#pod
#pod    sub description { "Long description" }
#pod
#pod Defines a longer command description that will be shown when the user asks for
#pod help on a specific command.
#pod
#pod =method arg0
#pod
#pod =method full_arg0
#pod
#pod   my $program_name = $app->arg0;
#pod
#pod   my $full_program_name = $app->full_arg0;
#pod
#pod These methods return the name of the program invoked to run this application.
#pod This is determined by inspecting C<$0> when the Dancer2::Bundled::App::Cmd object is
#pod instantiated, so it's probably correct, but doing weird things with Dancer2::Bundled::App::Cmd
#pod could lead to weird values from these methods.
#pod
#pod If the program was run like this:
#pod
#pod   knight!rjbs$ ~/bin/rpg dice 3d6
#pod
#pod Then the methods return:
#pod
#pod   arg0      - rpg
#pod   full_arg0 - /Users/rjbs/bin/rpg
#pod
#pod These values are captured when the Dancer2::Bundled::App::Cmd object is created, so it is safe to
#pod assign to C<$0> later.
#pod
#pod =cut

sub arg0      { $_[0]->{arg0} }
sub full_arg0 { $_[0]->{full_arg0} }

#pod =method prepare_command
#pod
#pod   my ($cmd, $opt, @args) = $app->prepare_command(@ARGV);
#pod
#pod This method will load the plugin for the requested command, use its options to
#pod parse the command line arguments, and eventually return everything necessary to
#pod actually execute the command.
#pod
#pod =cut

sub prepare_command {
  my ($self, @args) = @_;

  # figure out first-level dispatch
  my ($command, $opt, @sub_args) = $self->get_command(@args);

  # set up the global options (which we just determined)
  $self->set_global_options($opt);

  # find its plugin or else call default plugin (default default is help)
  if ($command) {
    $self->_prepare_command($command, $opt, @sub_args);
  } else {
    $self->_prepare_default_command($opt, @sub_args);
  }
}

sub _prepare_command {
  my ($self, $command, $opt, @args) = @_;
  if (my $plugin = $self->plugin_for($command)) {
    return $plugin->prepare($self, @args);
  } else {
    return $self->_bad_command($command, $opt, @args);
  }
}

sub _prepare_default_command {
  my ($self, $opt, @sub_args) = @_;
  $self->_prepare_command($self->default_command, $opt, @sub_args);
}

sub _bad_command {
  my ($self, $command, $opt, @args) = @_;
  print "Unrecognized command: $command.\n\nUsage:\n" if defined($command);

  # This should be class data so that, in Bizarro World, two Dancer2::Bundled::App::Cmds will not
  # conflict.
  our $_bad++;
  $self->prepare_command(qw(commands --stderr));
}

END { exit 1 if our $_bad };

#pod =method default_command
#pod
#pod This method returns the name of the command to run if none is given on the
#pod command line.  The default default is "help"
#pod
#pod =cut

sub default_command { "help" }

#pod =method execute_command
#pod
#pod   $app->execute_command($cmd, \%opt, @args);
#pod
#pod This method will invoke C<validate_args> and then C<run> on C<$cmd>.
#pod
#pod =cut

sub execute_command {
  my ($self, $cmd, $opt, @args) = @_;

  local our $active_cmd = $cmd;

  $cmd->validate_args($opt, \@args);
  $cmd->execute($opt, \@args);
}

#pod =method plugin_search_path
#pod
#pod This method returns the plugin_search_path as set.  The default implementation,
#pod if called on "YourDancer2::Bundled::App::Cmd" will return "YourDancer2::Bundled::App::Cmd::Command"
#pod
#pod This is a method because it's fun to override it with, for example:
#pod
#pod   use constant plugin_search_path => __PACKAGE__;
#pod
#pod =cut

sub _default_command_base {
  my ($self) = @_;
  my $class = ref $self || $self;
  return "$class\::Command";
}

sub _default_plugin_base {
  my ($self) = @_;
  my $class = ref $self || $self;
  return "$class\::Plugin";
}

sub plugin_search_path {
  my ($self) = @_;

  my $dcb = $self->_default_command_base;
  my $ccb = $dcb eq 'Dancer2::Bundled::App::Cmd::Command'
          ? $self->Dancer2::Bundled::App::Cmd::_default_command_base
          : $self->_default_command_base;

  my @default = ($ccb, $self->_default_plugin_base);

  if (ref $self) {
    return $self->{plugin_search_path} ||= \@default;
  } else {
    return \@default;
  }
}

#pod =method allow_any_unambiguous_abbrev
#pod
#pod If this method returns true (which, by default, it does I<not>), then any
#pod unambiguous abbreviation for a registered command name will be allowed as a
#pod means to use that command.  For example, given the following commands:
#pod
#pod   reticulate
#pod   reload
#pod   rasterize
#pod
#pod Then the user could use C<ret> for C<reticulate> or C<ra> for C<rasterize> and
#pod so on.
#pod
#pod =cut

sub allow_any_unambiguous_abbrev { return 0 }

#pod =method global_options
#pod
#pod   if ($cmd->app->global_options->{verbose}) { ... }
#pod
#pod This method returns the running application's global options as a hashref.  If
#pod there are no options specified, an empty hashref is returned.
#pod
#pod =cut

sub global_options {
	my $self = shift;
	return $self->{global_options} ||= {} if ref $self;
  return {};
}

#pod =method set_global_options
#pod
#pod   $app->set_global_options(\%opt);
#pod
#pod This method sets the global options.
#pod
#pod =cut

sub set_global_options {
  my ($self, $opt) = @_;
  return $self->{global_options} = $opt;
}

#pod =method command_names
#pod
#pod   my @names = $cmd->command_names;
#pod
#pod This returns the commands names which the Dancer2::Bundled::App::Cmd object will handle.
#pod
#pod =cut

sub command_names {
  my ($self) = @_;
  keys %{ $self->_command };
}

#pod =method command_groups
#pod
#pod   my @groups = $cmd->commands_groups;
#pod
#pod This method can be implemented to return a grouped list of command names with
#pod optional headers. Each group is given as arrayref and each header as string.
#pod If an empty list is returned, the commands plugin will show two groups without
#pod headers: the first group is for the "help" and "commands" commands, and all
#pod other commands are in the second group.
#pod
#pod =cut

sub command_groups { }

#pod =method command_plugins
#pod
#pod   my @plugins = $cmd->command_plugins;
#pod
#pod This method returns the package names of the plugins that implement the
#pod Dancer2::Bundled::App::Cmd object's commands.
#pod
#pod =cut

sub command_plugins {
  my ($self) = @_;
  my %seen = map {; $_ => 1 } values %{ $self->_command };
  keys %seen;
}

#pod =method plugin_for
#pod
#pod   my $plugin = $cmd->plugin_for($command);
#pod
#pod This method returns the plugin (module) for the given command.  If no plugin
#pod implements the command, it returns false.
#pod
#pod =cut

sub plugin_for {
  my ($self, $command) = @_;
  return unless $command;
  return unless exists $self->_command->{ $command };

  return $self->_command->{ $command };
}

#pod =method get_command
#pod
#pod   my ($command_name, $opt, @args) = $app->get_command(@args);
#pod
#pod Process arguments and into a command name and (optional) global options.
#pod
#pod =cut

sub get_command {
  my ($self, @args) = @_;

  my ($opt, $args, %fields)
    = $self->_process_args(\@args, $self->_global_option_processing_params);

  # map --help to help command
  if ($opt->{help}) {
      unshift @$args, 'help';
      delete $opt->{help};
  }

  my ($command, $rest) = $self->_cmd_from_args($args);

  $self->{usage} = $fields{usage};

  return ($command, $opt, @$rest);
}

sub _cmd_from_args {
  my ($self, $args) = @_;

  my $command = shift @$args;
  return ($command, $args);
}

sub _global_option_processing_params {
  my ($self, @args) = @_;

  return (
    $self->usage_desc(@args),
    $self->global_opt_spec(@args),
    { getopt_conf => [qw/pass_through/] },
  );
}

#pod =method usage
#pod
#pod   print $self->app->usage->text;
#pod
#pod Returns the usage object for the global options.
#pod
#pod =cut

sub usage { $_[0]{usage} };

#pod =method usage_desc
#pod
#pod The top level usage line. Looks something like
#pod
#pod   "yourapp <command> [options]"
#pod
#pod =cut

sub usage_desc {
  # my ($self) = @_; # no point in creating these ops, just to toss $self
  return "%c <command> %o";
}

#pod =method global_opt_spec
#pod
#pod Returns a list with help command unless C<no_help_plugin> has been specified or
#pod an empty list. Can be overridden for pre-dispatch option processing.  This is
#pod useful for flags like --verbose.
#pod
#pod =cut

sub global_opt_spec {
  my ($self) = @_;

  my $cmd = $self->{command};
  my %seen;
  my @help = grep { ! $seen{$_}++ }
             reverse sort map { s/^--?//; $_ }
             grep { $cmd->{$_} eq 'Dancer2::Bundled::App::Cmd::Command::help' } keys %$cmd;

  return (@help ? [ join('|', @help) => "show help" ] : ());
}

#pod =method usage_error
#pod
#pod   $self->usage_error("Something's wrong!");
#pod
#pod Used to die with nice usage output, during C<validate_args>.
#pod
#pod =cut

sub usage_error {
  my ($self, $error) = @_;
  die "Error: $error\nUsage: " . $self->_usage_text;
}

sub _usage_text {
  my ($self) = @_;
  my $text = $self->usage->text;
  $text =~ s/\A(\s+)/!/;
  return $text;
}

#pod =head1 TODO
#pod
#pod =for :list
#pod * publish and bring in Log::Speak (simple quiet/verbose output)
#pod * publish and use our internal enhanced describe_options
#pod * publish and use our improved simple input routines
#pod
#pod =cut

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Bundled::App::Cmd - write command line apps with less suffering

=head1 VERSION

version 0.331

=head1 SYNOPSIS

in F<yourcmd>:

  use YourApp;
  YourApp->run;

in F<YourApp.pm>:

  package YourApp;
  use Dancer2::Bundled::App::Cmd::Setup -app;
  1;

in F<YourApp/Command/blort.pm>:

  package YourApp::Command::blort;
  use YourApp -command;
  use strict; use warnings;

  sub abstract { "blortex algorithm" }

  sub description { "Long description on blortex algorithm" }

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

  knight!rjbs$ yourcmd blort --recheck

  All blorts successful.

=head1 DESCRIPTION

Dancer2::Bundled::App::Cmd is intended to make it easy to write complex command-line applications
without having to think about most of the annoying things usually involved.

For information on how to start using Dancer2::Bundled::App::Cmd, see L<Dancer2::Bundled::App::Cmd::Tutorial>.

=head1 METHODS

=head2 new

  my $cmd = Dancer2::Bundled::App::Cmd->new(\%arg);

This method returns a new Dancer2::Bundled::App::Cmd object.  During initialization, command
plugins will be loaded.

Valid arguments are:

  no_commands_plugin - if true, the command list plugin is not added

  no_help_plugin     - if true, the help plugin is not added

  no_version_plugin  - if true, the version plugin is not added

  show_version_cmd -   if true, the version command will be shown in the
                       command list

  plugin_search_path - The path to search for commands in. Defaults to
                       results of plugin_search_path method

If C<no_commands_plugin> is not given, L<Dancer2::Bundled::App::Cmd::Command::commands> will be
required, and it will be registered to handle all of its command names not
handled by other plugins.

If C<no_help_plugin> is not given, L<Dancer2::Bundled::App::Cmd::Command::help> will be required,
and it will be registered to handle all of its command names not handled by
other plugins. B<Note:> "help" is the default command, so if you do not load
the default help plugin, you should provide your own or override the
C<default_command> method.

If C<no_version_plugin> is not given, L<Dancer2::Bundled::App::Cmd::Command::version> will be
required to show the application's version with command C<--version>. By
default, the version command is not included in the command list. Pass
C<show_version_cmd> to include the version command in the list.

=head2 run

  $cmd->run;

This method runs the application.  If called the class, it will instantiate a
new Dancer2::Bundled::App::Cmd object to run.

It determines the requested command (generally by consuming the first
command-line argument), finds the plugin to handle that command, parses the
remaining arguments according to that plugin's rules, and runs the plugin.

It passes the contents of the global argument array (C<@ARGV>) to
L</C<prepare_command>>, but C<@ARGV> is not altered by running an Dancer2::Bundled::App::Cmd.

=head2 prepare_args

Normally Dancer2::Bundled::App::Cmd uses C<@ARGV> for its commandline arguments. You can override
this method to change that behavior for testing or otherwise.

=head2 default_args

If C<L</prepare_args>> is not changed and there are no arguments in C<@ARGV>,
this method is called and should return an arrayref to be used as the arguments
to the program.  By default, it returns an empty arrayref.

=head2 abstract 

   sub abstract { "command description" }

Defines the command abstract: a short description that will be printed in the
main command options list.

=head2 description

   sub description { "Long description" }

Defines a longer command description that will be shown when the user asks for
help on a specific command.

=head2 arg0

=head2 full_arg0

  my $program_name = $app->arg0;

  my $full_program_name = $app->full_arg0;

These methods return the name of the program invoked to run this application.
This is determined by inspecting C<$0> when the Dancer2::Bundled::App::Cmd object is
instantiated, so it's probably correct, but doing weird things with Dancer2::Bundled::App::Cmd
could lead to weird values from these methods.

If the program was run like this:

  knight!rjbs$ ~/bin/rpg dice 3d6

Then the methods return:

  arg0      - rpg
  full_arg0 - /Users/rjbs/bin/rpg

These values are captured when the Dancer2::Bundled::App::Cmd object is created, so it is safe to
assign to C<$0> later.

=head2 prepare_command

  my ($cmd, $opt, @args) = $app->prepare_command(@ARGV);

This method will load the plugin for the requested command, use its options to
parse the command line arguments, and eventually return everything necessary to
actually execute the command.

=head2 default_command

This method returns the name of the command to run if none is given on the
command line.  The default default is "help"

=head2 execute_command

  $app->execute_command($cmd, \%opt, @args);

This method will invoke C<validate_args> and then C<run> on C<$cmd>.

=head2 plugin_search_path

This method returns the plugin_search_path as set.  The default implementation,
if called on "YourDancer2::Bundled::App::Cmd" will return "YourDancer2::Bundled::App::Cmd::Command"

This is a method because it's fun to override it with, for example:

  use constant plugin_search_path => __PACKAGE__;

=head2 allow_any_unambiguous_abbrev

If this method returns true (which, by default, it does I<not>), then any
unambiguous abbreviation for a registered command name will be allowed as a
means to use that command.  For example, given the following commands:

  reticulate
  reload
  rasterize

Then the user could use C<ret> for C<reticulate> or C<ra> for C<rasterize> and
so on.

=head2 global_options

  if ($cmd->app->global_options->{verbose}) { ... }

This method returns the running application's global options as a hashref.  If
there are no options specified, an empty hashref is returned.

=head2 set_global_options

  $app->set_global_options(\%opt);

This method sets the global options.

=head2 command_names

  my @names = $cmd->command_names;

This returns the commands names which the Dancer2::Bundled::App::Cmd object will handle.

=head2 command_groups

  my @groups = $cmd->commands_groups;

This method can be implemented to return a grouped list of command names with
optional headers. Each group is given as arrayref and each header as string.
If an empty list is returned, the commands plugin will show two groups without
headers: the first group is for the "help" and "commands" commands, and all
other commands are in the second group.

=head2 command_plugins

  my @plugins = $cmd->command_plugins;

This method returns the package names of the plugins that implement the
Dancer2::Bundled::App::Cmd object's commands.

=head2 plugin_for

  my $plugin = $cmd->plugin_for($command);

This method returns the plugin (module) for the given command.  If no plugin
implements the command, it returns false.

=head2 get_command

  my ($command_name, $opt, @args) = $app->get_command(@args);

Process arguments and into a command name and (optional) global options.

=head2 usage

  print $self->app->usage->text;

Returns the usage object for the global options.

=head2 usage_desc

The top level usage line. Looks something like

  "yourapp <command> [options]"

=head2 global_opt_spec

Returns a list with help command unless C<no_help_plugin> has been specified or
an empty list. Can be overridden for pre-dispatch option processing.  This is
useful for flags like --verbose.

=head2 usage_error

  $self->usage_error("Something's wrong!");

Used to die with nice usage output, during C<validate_args>.

=head1 TODO

=over 4

=item *

publish and bring in Log::Speak (simple quiet/verbose output)

=item *

publish and use our internal enhanced describe_options

=item *

publish and use our improved simple input routines

=back

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 CONTRIBUTORS

=for stopwords Adam Prime ambs Andreas Hernitscheck A. Sinan Unur Chris 'BinGOs' Williams David Golden Steinbrunner Davor Cubranic Denis Ibaev Diab Jerius Glenn Fowler Ingy dot Net Jakob Voss Jérôme Quelin John SJ Anderson Karen Etheridge Kent Fredric Matthew Astley mokko Olivier Mengué Ricardo SIGNES Ryan C. Thompson Salvatore Bonaccorso Sergey Romanov Stephen Caldwell Yuval Kogman

=over 4

=item *

Adam Prime <aprime@oanda.com>

=item *

ambs <ambs@cpan.org>

=item *

Andreas Hernitscheck <andreash@lxhe.(none)>

=item *

A. Sinan Unur <nanis@cpan.org>

=item *

Chris 'BinGOs' Williams <chris@bingosnet.co.uk>

=item *

David Golden <dagolden@cpan.org>

=item *

David Steinbrunner <dsteinbrunner@pobox.com>

=item *

Davor Cubranic <cubranic@stat.ubc.ca>

=item *

Denis Ibaev <dionys@gmail.com>

=item *

Diab Jerius <djerius@cfa.harvard.edu>

=item *

Glenn Fowler <cebjyre@cpan.org>

=item *

Ingy dot Net <ingy@ingy.net>

=item *

Jakob Voss <jakob@nichtich.de>

=item *

Jakob Voss <voss@gbv.de>

=item *

Jérôme Quelin <jquelin@gmail.com>

=item *

John SJ Anderson <genehack@genehack.org>

=item *

Karen Etheridge <ether@cpan.org>

=item *

Kent Fredric <kentfredric@gmail.com>

=item *

Matthew Astley <mca@sanger.ac.uk>

=item *

mokko <mauricemengel@gmail.com>

=item *

Olivier Mengué <dolmen@cpan.org>

=item *

Ricardo SIGNES <rjbs@codesimply.com>

=item *

Ryan C. Thompson <rct@thompsonclan.org>

=item *

Salvatore Bonaccorso <carnil@debian.org>

=item *

Sergey Romanov <sromanov-dev@yandex.ru>

=item *

Stephen Caldwell <steve@campusexplorer.com>

=item *

Yuval Kogman <nuffin@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
