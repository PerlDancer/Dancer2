# ABSTRACT: file-based logging engine for Dancer2

package Dancer2::Logger::File;
use Carp 'carp';
use Moo;
use Dancer2::Core::Types;

with 'Dancer2::Core::Role::Logger';

use File::Spec;
use Fcntl qw(:flock SEEK_END);
use Dancer2::FileUtils qw(open_file);
use IO::File;

=head1 DESCRIPTION

This is a logging engine that allows you to save your logs to files on disk.

Logs are not automatically rotated.  Use a log rotation tool like
C<logrotate> in C<copytruncate> mode.

=head1 CONFIGURATION

The setting C<logger> should be set to C<File> in order to use this logging
engine in a Dancer2 application.

The follow attributes are supported:

=for :list
* log_dir -- directory path to hold log files. Defaults to F<logs> in the application directory
* file_name -- the name of the log file. Defaults to the environment name with a F<.log> suffix

Here is an example configuration that use this logger and stores logs in F</var/log/myapp>:

  logger: "File"

  engines:
    logger:
      File:
        log_dir: "/var/log/myapp"
        file_name: "myapp.log"

For backwards compatibility, the C<log_path> parameter may be given
at the top level of the config file to set the C<log_dir> attribute
and the C<log_file> parameter may be given to set the C<file_name>
attribute.

=cut

has log_dir => (
    is      => 'rw',
    isa     => Str,
    trigger => sub {
        my ($self, $dir) = @_;
        if (!-d $dir && !mkdir $dir) {
            return carp
              "Log directory \"$dir\" does not exist and unable to create it.";
        }
        return carp "Log directory \"$dir\" is not writable." if !-w $dir;
    },
    builder => '_build_log_dir',
    lazy    => 1,
);

sub _build_log_dir {
    my ($self) = @_;
      ;
    return defined($self->config->{log_path})
      ? $self->config->{log_path}
      : File::Spec->catdir($self->location, 'logs');
}

has file_name => (
    is      => 'ro',
    isa     => Str,
    builder => '_build_file_name',
    lazy    => 1
);

sub _build_file_name {
    my ($self) = @_;
    return defined($self->config->{log_file})
      ? $self->config->{log_file}
      : ($self->environment . ".log");
}

has log_file => (is => 'rw', isa => Str);
has fh => (is => 'rw');

sub BUILD {
    my $self = shift;
    my $logfile = File::Spec->catfile($self->log_dir, $self->file_name);

    my $fh;
    unless ($fh = open_file('>>', $logfile)) {
        carp "unable to create or append to $logfile";
        return;
    }
    $fh->autoflush;
    $self->log_file($logfile);
    $self->fh($fh);
}


=method log

Writes the log message to the file.

=cut

sub log {
    my ($self, $level, $message) = @_;
    my $fh = $self->fh;

    return unless (ref $fh && $fh->opened);

    flock($fh, LOCK_EX)
      or carp "locking logfile $self->{logfile} failed: $!";
    seek($fh, 0, SEEK_END);
    $fh->print($self->format_message($level => $message))
      or carp "writing to logfile $self->{logfile} failed";
    flock($fh, LOCK_UN)
      or carp "unlocking logfile $self->{logfile} failed: $!";
}

1;
