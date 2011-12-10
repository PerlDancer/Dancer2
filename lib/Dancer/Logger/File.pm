package Dancer::Logger::File;
use Carp 'carp';
use Moo;
use Dancer::Moo::Types;

with 'Dancer::Core::Role::Logger';

use File::Spec;
use Dancer::FileUtils qw(open_file);
use IO::File;

has log_dir => (
    is => 'rw',
    isa => sub { Str(@_) },
    trigger => sub {
        my ($self, $dir) = @_;
        if (! -d $dir && ! mkdir $dir) {
            return carp "Log directory \"$dir\" does not exist and unable to create it.";
        }
        return carp "Log directory \"$dir\" is not writable." if ! -w $dir;
    },
    builder => '_build_log_dir',
    lazy => 1,
);

sub _build_log_dir {
    my ($self) = @_;
    return $self->config->{logdir} ||
        File::Spec->catdir($self->location, 'logs');
}

has file_name => (
    is => 'ro',
    isa => sub { Str(@_) },
    builder => '_build_file_name',
    lazy => 1
);

sub _build_file_name {
    my ($self) = @_;
    my $env = $self->environment;
    return "$env.log";
}

has log_file => ( is => 'rw', isa => sub { Str(@_) } );
has fh => ( is => 'rw' );

sub BUILD {
    my $self = shift;
    my $logfile = File::Spec->catfile($self->log_dir, $self->file_name);

    my $fh;
    unless($fh = open_file('>>', $logfile)) {
        carp "unable to create or append to $logfile";
        return;
    }
    $fh->autoflush;
    $self->log_file($logfile);
    $self->fh($fh);
}

sub _log {
    my ($self, $level, $message) = @_;
    my $fh = $self->fh;

    return unless(ref $fh && $fh->opened);

    $fh->print($self->format_message($level => $message))
        or carp "writing to logfile $self->{logfile} failed";
}

1;

__END__

=head1 NAME

Dancer::Logger::File - file-based logging engine for Dancer

=head1 SYNOPSIS

=head1 DESCRIPTION

This is a file-based logging engine that allows you to save your logs to files
on disk.

=head1 METHODS

=head2 init

This method is called when C<< ->new() >> is called. It initializes the log
directory, creates if it doesn't already exist and opens the designated log
file.

=head2 logdir

Returns the log directory, decided by "logs" either in "appdir" setting.
It's also possible to specify a logs directory with the log_path option.

  setting log_path => $dir;

=head2 _log

Writes the log message to the file.

=head1 AUTHOR

Alexis Sukrieh

=head1 LICENSE AND COPYRIGHT

Copyright 2009-2010 Alexis Sukrieh.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

