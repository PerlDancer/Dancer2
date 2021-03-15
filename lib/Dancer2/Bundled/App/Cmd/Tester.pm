use strict;
use warnings;
package Dancer2::Bundled::App::Cmd::Tester;
$Dancer2::Bundled::App::Cmd::Tester::VERSION = '0.331';
# ABSTRACT: for capturing the result of running an app

#pod =head1 SYNOPSIS
#pod
#pod   use Test::More tests => 4;
#pod   use Dancer2::Bundled::App::Cmd::Tester;
#pod
#pod   use YourApp;
#pod
#pod   my $result = test_app(YourApp => [ qw(command --opt value) ]);
#pod
#pod   like($result->stdout, qr/expected output/, 'printed what we expected');
#pod
#pod   is($result->stderr, '', 'nothing sent to sderr');
#pod
#pod   is($result->error, undef, 'threw no exceptions');
#pod
#pod   my $result = test_app(YourApp => [ qw(command --opt value --quiet) ]);
#pod
#pod   is($result->output, '', 'absolutely no output with --quiet');
#pod
#pod =head1 DESCRIPTION
#pod
#pod One of the reasons that user-executed programs are so often poorly tested is
#pod that they are hard to test.  Dancer2::Bundled::App::Cmd::Tester is one of the tools App-Cmd
#pod provides to help make it easy to test Dancer2::Bundled::App::Cmd-based programs.
#pod
#pod It provides one routine: test_app.
#pod
#pod =method test_app
#pod
#pod B<Note>: while C<test_app> is a method, it is by default exported as a
#pod subroutine into the namespace that uses Dancer2::Bundled::App::Cmd::Tester.  In other words: you
#pod probably don't need to think about this as a method unless you want to subclass
#pod Dancer2::Bundled::App::Cmd::Tester.
#pod
#pod   my $result = test_app($app_class => \@argv_contents);
#pod
#pod This will locally set C<@ARGV> to simulate command line arguments, and will
#pod then call the C<run> method on the given application class (or application).
#pod Output to the standard output and standard error filehandles  will be captured.
#pod
#pod C<$result> is an Dancer2::Bundled::App::Cmd::Tester::Result object, which has methods to access
#pod the following data:
#pod
#pod   stdout - the output sent to stdout
#pod   stderr - the output sent to stderr
#pod   output - the combined output of stdout and stderr
#pod   error  - the exception thrown by running the application, or undef
#pod   run_rv - the return value of the run method (generally irrelevant)
#pod   exit_code - the numeric exit code that would've been issued (0 is 'okay')
#pod
#pod The output is captured using L<IO::TieCombine>, which I<can> ensure that the
#pod ordering is preserved in the combined output, but I<can't> capture the output
#pod of external programs.  You can reverse these tradeoffs by using
#pod L<Dancer2::Bundled::App::Cmd::Tester::CaptureExternal> instead.
#pod
#pod =cut

use Sub::Exporter::Util qw(curry_method);
use Sub::Exporter -setup => {
  exports => { test_app => curry_method },
  groups  => { default  => [ qw(test_app) ] },
};

our $TEST_IN_PROGRESS;
BEGIN {
  *CORE::GLOBAL::exit = sub {
    my ($rc) = @_;
    return CORE::exit($rc) unless $TEST_IN_PROGRESS;
    Dancer2::Bundled::App::Cmd::Tester::Exited->throw($rc);
  };
}

#pod =for Pod::Coverage result_class
#pod
#pod =cut

sub result_class { 'Dancer2::Bundled::App::Cmd::Tester::Result' }

sub test_app {
  my ($class, $app, $argv) = @_;

  local $Dancer2::Bundled::App::Cmd::_bad = 0;

  $app = $app->new unless ref($app) or $app->isa('Dancer2::Bundled::App::Cmd::Simple');

  my $result = $class->_run_with_capture($app, $argv);

  my $error = $result->{error};

  my $exit_code = defined $error ? ((0+$!)||-1) : 0;

  if ($error and eval { $error->isa('Dancer2::Bundled::App::Cmd::Tester::Exited') }) {
    $exit_code = $$error;
  }

  $exit_code =1 if $Dancer2::Bundled::App::Cmd::_bad && ! $exit_code;

  $class->result_class->new({
    app    => $app,
    exit_code => $exit_code,
    %$result,
  });
}

sub _run_with_capture {
  my ($class, $app, $argv) = @_;

  require IO::TieCombine;
  my $hub = IO::TieCombine->new;

  my $stdout = tie local *STDOUT, $hub, 'stdout';
  my $stderr = tie local *STDERR, $hub, 'stderr';

  my $run_rv;

  my $ok = eval {
    local $TEST_IN_PROGRESS = 1;
    local @ARGV = @$argv;
    $run_rv = $app->run;
    1;
  };

  my $error = $ok ? undef : $@;

  return {
    stdout => $hub->slot_contents('stdout'),
    stderr => $hub->slot_contents('stderr'),
    output => $hub->combined_contents,
    error  => $error,
    run_rv => $run_rv,
  };
}

{
  package Dancer2::Bundled::App::Cmd::Tester::Result;
$Dancer2::Bundled::App::Cmd::Tester::Result::VERSION = '0.331';
sub new {
    my ($class, $arg) = @_;
    bless $arg => $class;
  }

  for my $attr (qw(app stdout stderr output error run_rv exit_code)) {
    Sub::Install::install_sub({
      code => sub { $_[0]->{$attr} },
      as   => $attr,
    });
  }
}

{
  package Dancer2::Bundled::App::Cmd::Tester::Exited;
$Dancer2::Bundled::App::Cmd::Tester::Exited::VERSION = '0.331';
sub throw {
    my ($class, $code) = @_;
    $code = 0 unless defined $code;
    my $self = (bless \$code => $class);
    die $self;
  }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Bundled::App::Cmd::Tester - for capturing the result of running an app

=head1 VERSION

version 0.331

=head1 SYNOPSIS

  use Test::More tests => 4;
  use Dancer2::Bundled::App::Cmd::Tester;

  use YourApp;

  my $result = test_app(YourApp => [ qw(command --opt value) ]);

  like($result->stdout, qr/expected output/, 'printed what we expected');

  is($result->stderr, '', 'nothing sent to sderr');

  is($result->error, undef, 'threw no exceptions');

  my $result = test_app(YourApp => [ qw(command --opt value --quiet) ]);

  is($result->output, '', 'absolutely no output with --quiet');

=head1 DESCRIPTION

One of the reasons that user-executed programs are so often poorly tested is
that they are hard to test.  Dancer2::Bundled::App::Cmd::Tester is one of the tools App-Cmd
provides to help make it easy to test Dancer2::Bundled::App::Cmd-based programs.

It provides one routine: test_app.

=head1 METHODS

=head2 test_app

B<Note>: while C<test_app> is a method, it is by default exported as a
subroutine into the namespace that uses Dancer2::Bundled::App::Cmd::Tester.  In other words: you
probably don't need to think about this as a method unless you want to subclass
Dancer2::Bundled::App::Cmd::Tester.

  my $result = test_app($app_class => \@argv_contents);

This will locally set C<@ARGV> to simulate command line arguments, and will
then call the C<run> method on the given application class (or application).
Output to the standard output and standard error filehandles  will be captured.

C<$result> is an Dancer2::Bundled::App::Cmd::Tester::Result object, which has methods to access
the following data:

  stdout - the output sent to stdout
  stderr - the output sent to stderr
  output - the combined output of stdout and stderr
  error  - the exception thrown by running the application, or undef
  run_rv - the return value of the run method (generally irrelevant)
  exit_code - the numeric exit code that would've been issued (0 is 'okay')

The output is captured using L<IO::TieCombine>, which I<can> ensure that the
ordering is preserved in the combined output, but I<can't> capture the output
of external programs.  You can reverse these tradeoffs by using
L<Dancer2::Bundled::App::Cmd::Tester::CaptureExternal> instead.

=for Pod::Coverage result_class

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
