package Dancer2::Logger::File;
# ABSTRACT: file-based logging engine for Dancer2
$Dancer2::Logger::File::VERSION = '0.159002';
use Carp 'carp';
use Moo;
use Dancer2::Core::Types;

with 'Dancer2::Core::Role::Logger';

use File::Spec;
use Fcntl qw(:flock SEEK_END);
use Dancer2::FileUtils qw(open_file);
use IO::File;

has environment => (
    is       => 'ro',
    required => 1,
);

has location => (
    is       => 'ro',
    required => 1,
);

has log_dir => (
    is      => 'rw',
    isa     => sub {
        my $dir = shift;

        if ( !-d $dir && !mkdir $dir ) {
            die "log directory \"$dir\" does not exist and unable to create it.";
        }
        if ( !-w $dir ) {
            die "log directory \"$dir\" is not writable."
        }
    },
    lazy    => 1,
    builder => '_build_log_dir',
);

has file_name => (
    is      => 'ro',
    isa     => Str,
    builder => '_build_file_name',
    lazy    => 1
);

has log_file => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_log_file',
);

has fh => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_fh',
);

sub _build_log_dir { File::Spec->catdir( $_[0]->location, 'logs' ) }

sub _build_file_name {$_[0]->environment . ".log"}

sub _build_log_file {
    my $self = shift;
    return File::Spec->catfile( $self->log_dir, $self->file_name );
}

sub _build_fh {
    my $self    = shift;
    my $logfile = $self->log_file;

    my $fh;
    unless ( $fh = open_file( '>>', $logfile ) ) {
        carp "unable to create or append to $logfile";
        return;
    }

    $fh->autoflush;

    return $fh;
}

sub log {
    my ( $self, $level, $message ) = @_;
    my $fh = $self->fh;

    return unless ( ref $fh && $fh->opened );

    flock( $fh, LOCK_EX )
      or carp "locking logfile $self->{logfile} failed: $!";
    seek( $fh, 0, SEEK_END );
    $fh->print( $self->format_message( $level => $message ) )
      or carp "writing to logfile $self->{logfile} failed";
    flock( $fh, LOCK_UN )
      or carp "unlocking logfile $self->{logfile} failed: $!";
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Logger::File - file-based logging engine for Dancer2

=head1 VERSION

version 0.159002

=head1 DESCRIPTION

This is a logging engine that allows you to save your logs to files on disk.

Logs are not automatically rotated.  Use a log rotation tool like
C<logrotate> in C<copytruncate> mode.

=head1 METHODS

=head2 log($level, $message)

Writes the log message to the file.

=head1 CONFIGURATION

The setting C<logger> should be set to C<File> in order to use this logging
engine in a Dancer2 application.

The follow attributes are supported:

=for :list * log_dir -- directory path to hold log files. Defaults to F<logs> in the application directory
* file_name -- the name of the log file. Defaults to the environment name with a F<.log> suffix

Here is an example configuration that use this logger and stores logs in F</var/log/myapp>:

  logger: "File"

  engines:
    logger:
      File:
        log_dir: "/var/log/myapp"
        file_name: "myapp.log"

=head1 METHODS

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
