use strict;
use warnings;

package Dancer2::Bundled::App::Cmd::Command::version;
$Dancer2::Bundled::App::Cmd::Command::version::VERSION = '0.331';
use Dancer2::Bundled::App::Cmd::Command;
BEGIN { our @ISA = 'Dancer2::Bundled::App::Cmd::Command'; }

# ABSTRACT: display an app's version

#pod =head1 DESCRIPTION
#pod
#pod This command will display the program name, its base class
#pod with version number, and the full program name.
#pod
#pod =cut

sub command_names { qw/version --version/ }

sub version_for_display {
  $_[0]->version_package->VERSION
}

sub version_package {
  ref($_[0]->app)
}

sub execute {
  my ($self, $opts, $args) = @_;

  printf "%s (%s) version %s (%s)\n",
    $self->app->arg0, $self->version_package,
    $self->version_for_display, $self->app->full_arg0;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Bundled::App::Cmd::Command::version - display an app's version

=head1 VERSION

version 0.331

=head1 DESCRIPTION

This command will display the program name, its base class
with version number, and the full program name.

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
