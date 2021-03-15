use strict;
use warnings;

package Dancer2::Bundled::App::Cmd::Subdispatch;
$Dancer2::Bundled::App::Cmd::Subdispatch::VERSION = '0.331';
use Dancer2::Bundled::App::Cmd;
use Dancer2::Bundled::App::Cmd::Command;
BEGIN { our @ISA = qw(Dancer2::Bundled::App::Cmd::Command Dancer2::Bundled::App::Cmd) } 

# ABSTRACT: an Dancer2::Bundled::App::Cmd::Command that is also an Dancer2::Bundled::App::Cmd

#pod =method new
#pod
#pod A hackish new that allows us to have an Command instance before they normally
#pod exist.
#pod
#pod =cut

sub new {
	my ($inv, $fields, @args) = @_;
	if (ref $inv) {
		@{ $inv }{ keys %$fields } = values %$fields;
		return $inv;
	} else {
		$inv->SUPER::new($fields, @args);
	}
}

#pod =method prepare
#pod
#pod   my $subcmd = $subdispatch->prepare($app, @args);
#pod
#pod An overridden version of L<Dancer2::Bundled::App::Cmd::Command/prepare> that performs a new
#pod dispatch cycle.
#pod
#pod =cut

sub prepare {
	my ($class, $app, @args) = @_;

	my $self = $class->new({ app => $app });

	my ($subcommand, $opt, @sub_args) = $self->get_command(@args);

  $self->set_global_options($opt);

	if (defined $subcommand) {
    return $self->_prepare_command($subcommand, $opt, @sub_args);
  } else {
    if (@args) {
      return $self->_bad_command(undef, $opt, @sub_args);
    } else {
      return $self->_prepare_default_command($opt, @sub_args);
    }
  }
}

sub _plugin_prepare {
  my ($self, $plugin, @args) = @_;
  return $plugin->prepare($self->choose_parent_app($self->app, $plugin), @args);
}

#pod =method app
#pod
#pod   $subdispatch->app;
#pod
#pod This method returns the application that this subdispatch is a command of.
#pod
#pod =cut

sub app { $_[0]{app} }

#pod =method choose_parent_app
#pod
#pod   $subcmd->prepare(
#pod     $subdispatch->choose_parent_app($app, $opt, $plugin),
#pod     @$args
#pod   );
#pod
#pod A method that chooses whether the parent app or the subdispatch is going to be
#pod C<< $cmd->app >>.
#pod
#pod =cut

sub choose_parent_app {
	my ( $self, $app, $plugin ) = @_;

	if (
    $plugin->isa("Dancer2::Bundled::App::Cmd::Command::commands")
    or $plugin->isa("Dancer2::Bundled::App::Cmd::Command::help")
    or scalar keys %{ $self->global_options }
  ) {
		return $self;
	} else {
		return $app;
	}
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Bundled::App::Cmd::Subdispatch - an Dancer2::Bundled::App::Cmd::Command that is also an Dancer2::Bundled::App::Cmd

=head1 VERSION

version 0.331

=head1 METHODS

=head2 new

A hackish new that allows us to have an Command instance before they normally
exist.

=head2 prepare

  my $subcmd = $subdispatch->prepare($app, @args);

An overridden version of L<Dancer2::Bundled::App::Cmd::Command/prepare> that performs a new
dispatch cycle.

=head2 app

  $subdispatch->app;

This method returns the application that this subdispatch is a command of.

=head2 choose_parent_app

  $subcmd->prepare(
    $subdispatch->choose_parent_app($app, $opt, $plugin),
    @$args
  );

A method that chooses whether the parent app or the subdispatch is going to be
C<< $cmd->app >>.

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
