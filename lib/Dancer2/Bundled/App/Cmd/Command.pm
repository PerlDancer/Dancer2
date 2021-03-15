use strict;
use warnings;

package Dancer2::Bundled::App::Cmd::Command;
$Dancer2::Bundled::App::Cmd::Command::VERSION = '0.331';
use Dancer2::Bundled::App::Cmd::ArgProcessor;
BEGIN { our @ISA = 'Dancer2::Bundled::App::Cmd::ArgProcessor' };

# ABSTRACT: a base class for Dancer2::Bundled::App::Cmd commands

use Carp ();

#pod =method prepare
#pod
#pod   my ($cmd, $opt, $args) = $class->prepare($app, @args);
#pod
#pod This method is the primary way in which Dancer2::Bundled::App::Cmd::Command objects are built.
#pod Given the remaining command line arguments meant for the command, it returns
#pod the Command object, parsed options (as a hashref), and remaining arguments (as
#pod an arrayref).
#pod
#pod In the usage above, C<$app> is the Dancer2::Bundled::App::Cmd object that is invoking the
#pod command.
#pod
#pod =cut

sub prepare {
  my ($class, $app, @args) = @_;

  my ($opt, $args, %fields)
    = $class->_process_args(\@args, $class->_option_processing_params($app));

  return (
    $class->new({ app => $app, %fields }),
    $opt,
    @$args,
  );
}

sub _option_processing_params {
  my ($class, @args) = @_;

  return (
    $class->usage_desc(@args),
    $class->opt_spec(@args),
  );
}

#pod =method new
#pod
#pod This returns a new instance of the command plugin.  Probably only C<prepare>
#pod should use this.
#pod
#pod =cut

sub new {
  my ($class, $arg) = @_;
  bless $arg => $class;
}

#pod =method execute
#pod
#pod   $command_plugin->execute(\%opt, \@args);
#pod
#pod This method does whatever it is the command should do!  It is passed a hash
#pod reference of the parsed command-line options and an array reference of left
#pod over arguments.
#pod
#pod If no C<execute> method is defined, it will try to call C<run> -- but it will
#pod warn about this behavior during testing, to remind you to fix the method name!
#pod
#pod =cut

sub execute {
  my $class = shift;

  if (my $run = $class->can('run')) {
    warn "Dancer2::Bundled::App::Cmd::Command subclasses should implement ->execute not ->run"
      if $ENV{HARNESS_ACTIVE};

    return $class->$run(@_);
  }

  Carp::croak ref($class) . " does not implement mandatory method 'execute'\n";
}

#pod =method app
#pod
#pod This method returns the Dancer2::Bundled::App::Cmd object into which this command is plugged.
#pod
#pod =cut

sub app { $_[0]->{app}; }

#pod =method usage
#pod
#pod This method returns the usage object for this command.  (See
#pod L<Getopt::Long::Descriptive>).
#pod
#pod =cut

sub usage { $_[0]->{usage}; }

#pod =method command_names
#pod
#pod This method returns a list of command names handled by this plugin. The
#pod first item returned is the 'canonical' name of the command.
#pod
#pod If this method is not overridden by an Dancer2::Bundled::App::Cmd::Command subclass, it will
#pod return the last part of the plugin's package name, converted to lowercase.
#pod For example, YourDancer2::Bundled::App::Cmd::Command::Init will, by default, handle the command
#pod "init".
#pod
#pod Subclasses should generally get the superclass value of C<command_names>
#pod and then append aliases.
#pod
#pod =cut

sub command_names {
  # from UNIVERSAL::moniker
  (ref( $_[0] ) || $_[0]) =~ /([^:]+)$/;
  return lc $1;
}

#pod =method usage_desc
#pod
#pod This method should be overridden to provide a usage string.  (This is the first
#pod argument passed to C<describe_options> from Getopt::Long::Descriptive.)
#pod
#pod If not overridden, it returns "%c COMMAND %o";  COMMAND is the first item in
#pod the result of the C<command_names> method.
#pod
#pod =cut

sub usage_desc {
  my ($self) = @_;

  my ($command) = $self->command_names;
  return "%c $command %o"
}

#pod =method opt_spec
#pod
#pod This method should be overridden to provide option specifications.  (This is
#pod list of arguments passed to C<describe_options> from Getopt::Long::Descriptive,
#pod after the first.)
#pod
#pod If not overridden, it returns an empty list.
#pod
#pod =cut

sub opt_spec {
  return;
}

#pod =method validate_args
#pod
#pod   $command_plugin->validate_args(\%opt, \@args);
#pod
#pod This method is passed a hashref of command line options (as processed by
#pod Getopt::Long::Descriptive) and an arrayref of leftover arguments.  It may throw
#pod an exception (preferably by calling C<usage_error>, below) if they are invalid,
#pod or it may do nothing to allow processing to continue.
#pod
#pod =cut

sub validate_args { }

#pod =method usage_error
#pod
#pod   $self->usage_error("This command must not be run by root!");
#pod
#pod This method should be called to die with human-friendly usage output, during
#pod C<validate_args>.
#pod
#pod =cut

sub usage_error {
  my ( $self, $error ) = @_;
  die "Error: $error\nUsage: " . $self->_usage_text;
}

sub _usage_text {
  my ($self) = @_;
  local $@;
  join "\n", eval { $self->app->_usage_text }, eval { $self->usage->text };
}

#pod =method abstract
#pod
#pod This method returns a short description of the command's purpose.  If this
#pod method is not overridden, it will return the abstract from the module's Pod.
#pod If it can't find the abstract, it will look for a comment starting with
#pod "ABSTRACT:" like the ones used by L<Pod::Weaver::Section::Name>.
#pod
#pod =cut

# stolen from ExtUtils::MakeMaker
sub abstract {
  my ($class) = @_;
  $class = ref $class if ref $class;

  my $result;
  my $weaver_abstract;

  # classname to filename
  (my $pm_file = $class) =~ s!::!/!g;
  $pm_file .= '.pm';
  $pm_file = $INC{$pm_file} or return "(unknown)";

  # if the pm file exists, open it and parse it
  open my $fh, "<", $pm_file or return "(unknown)";

  local $/ = "\n";
  my $inpod;

  while (local $_ = <$fh>) {
    # =cut toggles, it doesn't end :-/
    $inpod = /^=cut/ ? !$inpod : $inpod || /^=(?!cut)/;

    if (/#+\s*ABSTRACT: (.*)/){
      # takes ABSTRACT: ... if no POD defined yet
      $weaver_abstract = $1;
    }

    next unless $inpod;
    chomp;

    next unless /^(?:$class\s-\s)(.*)/;

    $result = $1;
    last;
  }

  return $result || $weaver_abstract || "(unknown)";
}

#pod =method description
#pod
#pod This method can be overridden to provide full option description. It
#pod is used by the built-in L<help|Dancer2::Bundled::App::Cmd::Command::help> command.
#pod
#pod If not overridden, it uses L<Pod::Usage> to extract the description
#pod from the module's Pod DESCRIPTION section or the empty string.
#pod
#pod =cut

sub description {
    my ($class) = @_;
    $class = ref $class if ref $class;

    # classname to filename
    (my $pm_file = $class) =~ s!::!/!g;
    $pm_file .= '.pm';
    $pm_file = $INC{$pm_file} or return '';

    open my $input, "<", $pm_file or return '';

    my $descr = "";
    open my $output, ">", \$descr;

    require Pod::Usage;
    Pod::Usage::pod2usage( -input => $input,
               -output => $output,
               -exit => "NOEXIT", 
               -verbose => 99,
               -sections => "DESCRIPTION",
               indent => 0
    );
    $descr =~ s/Description:\n//m;
    chomp $descr;

    return $descr;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Bundled::App::Cmd::Command - a base class for Dancer2::Bundled::App::Cmd commands

=head1 VERSION

version 0.331

=head1 METHODS

=head2 prepare

  my ($cmd, $opt, $args) = $class->prepare($app, @args);

This method is the primary way in which Dancer2::Bundled::App::Cmd::Command objects are built.
Given the remaining command line arguments meant for the command, it returns
the Command object, parsed options (as a hashref), and remaining arguments (as
an arrayref).

In the usage above, C<$app> is the Dancer2::Bundled::App::Cmd object that is invoking the
command.

=head2 new

This returns a new instance of the command plugin.  Probably only C<prepare>
should use this.

=head2 execute

  $command_plugin->execute(\%opt, \@args);

This method does whatever it is the command should do!  It is passed a hash
reference of the parsed command-line options and an array reference of left
over arguments.

If no C<execute> method is defined, it will try to call C<run> -- but it will
warn about this behavior during testing, to remind you to fix the method name!

=head2 app

This method returns the Dancer2::Bundled::App::Cmd object into which this command is plugged.

=head2 usage

This method returns the usage object for this command.  (See
L<Getopt::Long::Descriptive>).

=head2 command_names

This method returns a list of command names handled by this plugin. The
first item returned is the 'canonical' name of the command.

If this method is not overridden by an Dancer2::Bundled::App::Cmd::Command subclass, it will
return the last part of the plugin's package name, converted to lowercase.
For example, YourDancer2::Bundled::App::Cmd::Command::Init will, by default, handle the command
"init".

Subclasses should generally get the superclass value of C<command_names>
and then append aliases.

=head2 usage_desc

This method should be overridden to provide a usage string.  (This is the first
argument passed to C<describe_options> from Getopt::Long::Descriptive.)

If not overridden, it returns "%c COMMAND %o";  COMMAND is the first item in
the result of the C<command_names> method.

=head2 opt_spec

This method should be overridden to provide option specifications.  (This is
list of arguments passed to C<describe_options> from Getopt::Long::Descriptive,
after the first.)

If not overridden, it returns an empty list.

=head2 validate_args

  $command_plugin->validate_args(\%opt, \@args);

This method is passed a hashref of command line options (as processed by
Getopt::Long::Descriptive) and an arrayref of leftover arguments.  It may throw
an exception (preferably by calling C<usage_error>, below) if they are invalid,
or it may do nothing to allow processing to continue.

=head2 usage_error

  $self->usage_error("This command must not be run by root!");

This method should be called to die with human-friendly usage output, during
C<validate_args>.

=head2 abstract

This method returns a short description of the command's purpose.  If this
method is not overridden, it will return the abstract from the module's Pod.
If it can't find the abstract, it will look for a comment starting with
"ABSTRACT:" like the ones used by L<Pod::Weaver::Section::Name>.

=head2 description

This method can be overridden to provide full option description. It
is used by the built-in L<help|Dancer2::Bundled::App::Cmd::Command::help> command.

If not overridden, it uses L<Pod::Usage> to extract the description
from the module's Pod DESCRIPTION section or the empty string.

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
