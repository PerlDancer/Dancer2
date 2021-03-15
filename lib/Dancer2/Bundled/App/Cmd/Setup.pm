use strict;
use warnings;
package Dancer2::Bundled::App::Cmd::Setup;
$Dancer2::Bundled::App::Cmd::Setup::VERSION = '0.331';
# ABSTRACT: helper for setting up Dancer2::Bundled::App::Cmd classes

#pod =head1 OVERVIEW
#pod
#pod Dancer2::Bundled::App::Cmd::Setup is a helper library, used to set up base classes that will be
#pod used as part of an Dancer2::Bundled::App::Cmd program.  For the most part you should refer to
#pod L<the tutorial|Dancer2::Bundled::App::Cmd::Tutorial> for how you should use this library.
#pod
#pod This class is useful in three scenarios:
#pod
#pod =begin :list
#pod
#pod = when writing your Dancer2::Bundled::App::Cmd subclass
#pod
#pod Instead of writing:
#pod
#pod   package MyApp;
#pod   use base 'Dancer2::Bundled::App::Cmd';
#pod
#pod ...you can write:
#pod
#pod   package MyApp;
#pod   use Dancer2::Bundled::App::Cmd::Setup -app;
#pod
#pod The benefits of doing this are mostly minor, and relate to sanity-checking your
#pod class.  The significant benefit is that this form allows you to specify
#pod plugins, as in:
#pod
#pod   package MyApp;
#pod   use Dancer2::Bundled::App::Cmd::Setup -app => { plugins => [ 'Prompt' ] };
#pod
#pod Plugins are described in L<Dancer2::Bundled::App::Cmd::Tutorial> and L<Dancer2::Bundled::App::Cmd::Plugin>.
#pod
#pod = when writing abstract base classes for commands
#pod
#pod That is: when you write a subclass of L<Dancer2::Bundled::App::Cmd::Command> that is intended for
#pod other commands to use as their base class, you should use Dancer2::Bundled::App::Cmd::Setup.  For
#pod example, if you want all the commands in MyApp to inherit from MyApp::Command,
#pod you may want to write that package like this:
#pod
#pod   package MyApp::Command;
#pod   use Dancer2::Bundled::App::Cmd::Setup -command;
#pod
#pod Do not confuse this with the way you will write specific commands:
#pod
#pod   package MyApp::Command::mycmd;
#pod   use MyApp -command;
#pod
#pod Again, this form mostly performs some validation and setup behind the scenes
#pod for you.  You can use C<L<base>> if you prefer.
#pod
#pod = when writing Dancer2::Bundled::App::Cmd plugins
#pod
#pod L<Dancer2::Bundled::App::Cmd::Plugin> is a mechanism that allows an Dancer2::Bundled::App::Cmd class to inject code
#pod into all its command classes, providing them with utility routines.
#pod
#pod To write a plugin, you must use Dancer2::Bundled::App::Cmd::Setup.  As seen above, you must also
#pod use Dancer2::Bundled::App::Cmd::Setup to set up your Dancer2::Bundled::App::Cmd subclass if you wish to consume
#pod plugins.
#pod
#pod For more information on writing plugins, see L<Dancer2::Bundled::App::Cmd::Manual> and
#pod L<Dancer2::Bundled::App::Cmd::Plugin>.
#pod
#pod =end :list
#pod
#pod =cut

use Dancer2::Bundled::App::Cmd ();
use Dancer2::Bundled::App::Cmd::Command ();
use Dancer2::Bundled::App::Cmd::Plugin ();
use Carp ();
use Data::OptList ();
use String::RewritePrefix ();

# 0.06 is needed for load_optional_class
use Class::Load 0.06 qw();

use Sub::Exporter -setup => {
  -as     => '_import',
  exports => [ qw(foo) ],
  collectors => [
    -app     => \'_make_app_class',
    -command => \'_make_command_class',
    -plugin  => \'_make_plugin_class',
  ],
};

sub import {
  goto &_import;
}

sub _app_base_class { 'Dancer2::Bundled::App::Cmd' }

sub _make_app_class {
  my ($self, $val, $data) = @_;
  my $into = $data->{into};

  $val ||= {};
  Carp::confess "invalid argument to -app setup"
    if grep { $_ ne 'plugins' } keys %$val;

  Carp::confess "app setup requested on Dancer2::Bundled::App::Cmd subclass $into"
    if $into->isa('Dancer2::Bundled::App::Cmd');

  $self->_make_x_isa_y($into, $self->_app_base_class);

  if ( ! Class::Load::load_optional_class( $into->_default_command_base ) ) {
    my $base = $self->_command_base_class;
    Sub::Install::install_sub({
      code => sub { $base },
      into => $into,
      as   => '_default_command_base',
    });
  }

  # TODO Check this is right. -- kentnl, 2010-12
  #
  #  my $want_plugin_base = $self->_plugin_base_class;
  my $want_plugin_base = 'Dancer2::Bundled::App::Cmd::Plugin';

  my @plugins;
  for my $plugin (@{ $val->{plugins} || [] }) {
    $plugin = String::RewritePrefix->rewrite(
      {
        ''  => 'Dancer2::Bundled::App::Cmd::Plugin::',
        '=' => ''
      },
      $plugin,
    );
    Class::Load::load_class( $plugin );
    unless( $plugin->isa( $want_plugin_base ) ){
        die "$plugin is not a " . $want_plugin_base;
    }
    push @plugins, $plugin;
  }

  Sub::Install::install_sub({
    code => sub { @plugins },
    into => $into,
    as   => '_plugin_plugins',
  });

  return 1;
}

sub _command_base_class { 'Dancer2::Bundled::App::Cmd::Command' }

sub _make_command_class {
  my ($self, $val, $data) = @_;
  my $into = $data->{into};

  Carp::confess "command setup requested on Dancer2::Bundled::App::Cmd::Command subclass $into"
    if $into->isa('Dancer2::Bundled::App::Cmd::Command');

  $self->_make_x_isa_y($into, $self->_command_base_class);

  return 1;
}

sub _make_x_isa_y {
  my ($self, $x, $y) = @_;

  no strict 'refs';
  push @{"$x\::ISA"}, $y;
}

sub _plugin_base_class { 'Dancer2::Bundled::App::Cmd::Plugin' }
sub _make_plugin_class {
  my ($self, $val, $data) = @_;
  my $into = $data->{into};

  Carp::confess "plugin setup requested on Dancer2::Bundled::App::Cmd::Plugin subclass $into"
    if $into->isa('Dancer2::Bundled::App::Cmd::Plugin');

  Carp::confess "plugin setup requires plugin configuration" unless $val;

  $self->_make_x_isa_y($into, $self->_plugin_base_class);

  # In this special case, exporting everything by default is the sensible thing
  # to do. -- rjbs, 2008-03-31
  $val->{groups} = [ default => [ -all ] ] unless $val->{groups};

  my @exports;
  for my $pair (@{ Data::OptList::mkopt($val->{exports}) }) {
    push @exports, $pair->[0], ($pair->[1] || \'_faux_curried_method');
  }

  $val->{exports} = \@exports;

  Sub::Exporter::setup_exporter({
    %$val,
    into => $into,
    as   => 'import_from_plugin',
  });

  return 1;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Bundled::App::Cmd::Setup - helper for setting up Dancer2::Bundled::App::Cmd classes

=head1 VERSION

version 0.331

=head1 OVERVIEW

Dancer2::Bundled::App::Cmd::Setup is a helper library, used to set up base classes that will be
used as part of an Dancer2::Bundled::App::Cmd program.  For the most part you should refer to
L<the tutorial|Dancer2::Bundled::App::Cmd::Tutorial> for how you should use this library.

This class is useful in three scenarios:

=over 4

=item when writing your Dancer2::Bundled::App::Cmd subclass

Instead of writing:

  package MyApp;
  use base 'Dancer2::Bundled::App::Cmd';

...you can write:

  package MyApp;
  use Dancer2::Bundled::App::Cmd::Setup -app;

The benefits of doing this are mostly minor, and relate to sanity-checking your
class.  The significant benefit is that this form allows you to specify
plugins, as in:

  package MyApp;
  use Dancer2::Bundled::App::Cmd::Setup -app => { plugins => [ 'Prompt' ] };

Plugins are described in L<Dancer2::Bundled::App::Cmd::Tutorial> and L<Dancer2::Bundled::App::Cmd::Plugin>.

=item when writing abstract base classes for commands

That is: when you write a subclass of L<Dancer2::Bundled::App::Cmd::Command> that is intended for
other commands to use as their base class, you should use Dancer2::Bundled::App::Cmd::Setup.  For
example, if you want all the commands in MyApp to inherit from MyApp::Command,
you may want to write that package like this:

  package MyApp::Command;
  use Dancer2::Bundled::App::Cmd::Setup -command;

Do not confuse this with the way you will write specific commands:

  package MyApp::Command::mycmd;
  use MyApp -command;

Again, this form mostly performs some validation and setup behind the scenes
for you.  You can use C<L<base>> if you prefer.

=item when writing Dancer2::Bundled::App::Cmd plugins

L<Dancer2::Bundled::App::Cmd::Plugin> is a mechanism that allows an Dancer2::Bundled::App::Cmd class to inject code
into all its command classes, providing them with utility routines.

To write a plugin, you must use Dancer2::Bundled::App::Cmd::Setup.  As seen above, you must also
use Dancer2::Bundled::App::Cmd::Setup to set up your Dancer2::Bundled::App::Cmd subclass if you wish to consume
plugins.

For more information on writing plugins, see L<Dancer2::Bundled::App::Cmd::Manual> and
L<Dancer2::Bundled::App::Cmd::Plugin>.

=back

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
