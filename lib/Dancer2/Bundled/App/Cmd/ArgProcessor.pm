use strict;
use warnings;

package Dancer2::Bundled::App::Cmd::ArgProcessor;
$Dancer2::Bundled::App::Cmd::ArgProcessor::VERSION = '0.331';
# ABSTRACT: Dancer2::Bundled::App::Cmd-specific wrapper for Getopt::Long::Descriptive

sub _process_args {
  my ($class, $args, @params) = @_;
  local @ARGV = @$args;

  require Getopt::Long::Descriptive;
  Getopt::Long::Descriptive->VERSION(0.084);

  my ($opt, $usage) = Getopt::Long::Descriptive::describe_options(@params);

  return (
    $opt,
    [ @ARGV ], # whatever remained
    usage => $usage,
  );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Bundled::App::Cmd::ArgProcessor - Dancer2::Bundled::App::Cmd-specific wrapper for Getopt::Long::Descriptive

=head1 VERSION

version 0.331

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
