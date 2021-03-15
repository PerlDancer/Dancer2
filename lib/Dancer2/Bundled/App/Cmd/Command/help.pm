use strict;
use warnings;

package Dancer2::Bundled::App::Cmd::Command::help;
$Dancer2::Bundled::App::Cmd::Command::help::VERSION = '0.331';
use Dancer2::Bundled::App::Cmd::Command;
BEGIN { our @ISA = 'Dancer2::Bundled::App::Cmd::Command'; }

# ABSTRACT: display a command's help screen

#pod =head1 DESCRIPTION
#pod
#pod This command will either list all of the application commands and their
#pod abstracts, or display the usage screen for a subcommand with its
#pod description.
#pod
#pod =head1 USAGE
#pod
#pod The help text is generated from three sources:
#pod
#pod =for :list
#pod * The C<usage_desc> method
#pod * The C<description> method
#pod * The C<opt_spec> data structure
#pod
#pod The C<usage_desc> method provides the opening usage line, following the
#pod specification described in L<Getopt::Long::Descriptive>.  In some cases,
#pod the default C<usage_desc> in L<Dancer2::Bundled::App::Cmd::Command> may be sufficient and
#pod you will only need to override it to provide additional command line
#pod usage information.
#pod
#pod The C<opt_spec> data structure is used with L<Getopt::Long::Descriptive>
#pod to generate the description of the options.
#pod
#pod Subcommand classes should override the C<discription> method to provide
#pod additional information that is prepended before the option descriptions.
#pod
#pod For example, consider the following subcommand module:
#pod
#pod   package YourApp::Command::initialize;
#pod
#pod   # This is the default from Dancer2::Bundled::App::Cmd::Command
#pod   sub usage_desc {
#pod     my ($self) = @_;
#pod     my $desc = $self->SUPER::usage_desc; # "%c COMMAND %o"
#pod     return "$desc [DIRECTORY]";
#pod   }
#pod
#pod   sub description {
#pod     return "The initialize command prepares the application...";
#pod   }
#pod
#pod   sub opt_spec {
#pod     return (
#pod       [ "skip-refs|R",  "skip reference checks during init", ],
#pod       [ "values|v=s@",  "starting values", { default => [ 0, 1, 3 ] } ],
#pod     );
#pod   }
#pod
#pod   ...
#pod
#pod That module would generate help output like this:
#pod
#pod   $ yourapp help initialize
#pod   yourapp initialize [-Rv] [long options...] [DIRECTORY]
#pod
#pod   The initialize command prepares the application...
#pod
#pod         --help            This usage screen
#pod         -R --skip-refs    skip reference checks during init
#pod         -v --values       starting values
#pod
#pod =cut

sub usage_desc { '%c help [subcommand]' }

sub command_names { qw/help --help -h -?/ }

sub execute {
  my ($self, $opts, $args) = @_;

  if (!@$args) {
    print $self->app->usage->text . "\n";

    print "Available commands:\n\n";

    $self->app->execute_command( $self->app->_prepare_command("commands") );
  } else {
    my ($cmd, $opt, $args) = $self->app->prepare_command(@$args);

    local $@;
    my $desc = $cmd->description;
    $desc = "\n$desc" if length $desc;

    my $ut = join "\n",
      eval { $cmd->usage->leader_text },
      $desc,
      eval { $cmd->usage->option_text };

    print "$ut\n";
  }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Bundled::App::Cmd::Command::help - display a command's help screen

=head1 VERSION

version 0.331

=head1 DESCRIPTION

This command will either list all of the application commands and their
abstracts, or display the usage screen for a subcommand with its
description.

=head1 USAGE

The help text is generated from three sources:

=over 4

=item *

The C<usage_desc> method

=item *

The C<description> method

=item *

The C<opt_spec> data structure

=back

The C<usage_desc> method provides the opening usage line, following the
specification described in L<Getopt::Long::Descriptive>.  In some cases,
the default C<usage_desc> in L<Dancer2::Bundled::App::Cmd::Command> may be sufficient and
you will only need to override it to provide additional command line
usage information.

The C<opt_spec> data structure is used with L<Getopt::Long::Descriptive>
to generate the description of the options.

Subcommand classes should override the C<discription> method to provide
additional information that is prepended before the option descriptions.

For example, consider the following subcommand module:

  package YourApp::Command::initialize;

  # This is the default from Dancer2::Bundled::App::Cmd::Command
  sub usage_desc {
    my ($self) = @_;
    my $desc = $self->SUPER::usage_desc; # "%c COMMAND %o"
    return "$desc [DIRECTORY]";
  }

  sub description {
    return "The initialize command prepares the application...";
  }

  sub opt_spec {
    return (
      [ "skip-refs|R",  "skip reference checks during init", ],
      [ "values|v=s@",  "starting values", { default => [ 0, 1, 3 ] } ],
    );
  }

  ...

That module would generate help output like this:

  $ yourapp help initialize
  yourapp initialize [-Rv] [long options...] [DIRECTORY]

  The initialize command prepares the application...

        --help            This usage screen
        -R --skip-refs    skip reference checks during init
        -v --values       starting values

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
