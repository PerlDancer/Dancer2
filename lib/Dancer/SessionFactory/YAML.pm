package Dancer::SessionFactory::YAML;

# ABSTRACT: YAML-file-based session backend for Dancer

use Moo;
use Dancer::Core::Types;
use Carp;
use Fcntl ':flock';
use Dancer::FileUtils qw(path set_file_mode);
use YAML::Any;

with 'Dancer::Core::Role::SessionFactory';

=attr session_dir

Where to store the session files.

=cut

has session_dir => (
    is      => 'ro',
    isa     => Str,
    default => sub { path('.', 'sessions') },
);

sub BUILD {
    my $self = shift;

    if (!-d $self->session_dir) {
        mkdir $self->session_dir
          or croak "Unable to create session dir : "
          . $self->session_dir . ' : '
          . $!;
    }
}

sub _sessions {
    my ($self) = @_;
    my $sessions = [];

    opendir(my $dh, $self->session_dir)
      or croak "Unable to open directory " . $self->session_dir . " : $!";

    while (my $file = readdir($dh)) {
        next if $file eq '.' || $file eq '..';
        if ($file =~ /(\w+)\.yml/) {
            push @{$sessions}, $1;
        }
    }
    closedir($dh);

    return $sessions;
}

sub yaml_file {
    my ($self, $id) = @_;
    return path($self->session_dir, "$id.yml");
}

sub _retrieve {
    my ($self, $id) = @_;
    my $session_file = $self->yaml_file($id);

    return unless -f $session_file;

    open my $fh, '+<', $session_file or die "Can't open '$session_file': $!\n";
    flock $fh, LOCK_EX or die "Can't lock file '$session_file': $!\n";
    my $data = YAML::Any::LoadFile($fh);
    close $fh or die "Can't close '$session_file': $!\n";

    return $data;
}

sub _destroy {
    my ($self, $id) = @_;
    my $session_file = $self->yaml_file($id);
    return if !-f $session_file;

    unlink $session_file;
}

sub _flush {
    my ($self, $id, $data) = @_;
    my $session_file = $self->yaml_file($id);

    open my $fh, '>', $session_file or die "Can't open '$session_file': $!\n";
    flock $fh, LOCK_EX or die "Can't lock file '$session_file': $!\n";
    set_file_mode($fh);
    print {$fh} YAML::Any::Dump($data);
    close $fh or die "Can't close '$session_file': $!\n";

    return $data;
}

1;
__END__

=head1 DESCRIPTION

This module implements a session engine based on YAML files. Session are stored
in a I<session_dir> as YAML files. The idea behind this module was to provide a
human-readable session storage for the developer.

This backend is intended to be used in development environments, when digging
inside a session can be useful.

This backend an perfectly be used in production environments, but two things
should be kept in mind: The content of the session files is in plain text, and
the session files should be purged by a CRON job.

=head1 CONFIGURATION

The setting B<session> should be set to C<YAML> in order to use this session
engine in a Dancer application.

Files will be stored to the value of the setting C<session_dir>, whose default
value is C<appdir/sessions>.

Here is an example configuration that use this session engine and stores session
files in /tmp/dancer-sessions

    session: "YAML"
    session_dir: "/tmp/dancer-sessions"


=head1 DEPENDENCY

This module depends on L<YAML>.

=head1 SEE ALSO

See L<Dancer::Session> for details about session usage in route handlers.

=cut
