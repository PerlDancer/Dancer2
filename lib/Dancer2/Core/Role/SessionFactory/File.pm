package Dancer2::Core::Role::SessionFactory::File;
# ABSTRACT: Role for file-based session factories

use Moo::Role;
with 'Dancer2::Core::Role::SessionFactory';

use Carp 'croak';
use Dancer2::Core::Types;
use Dancer2::FileUtils qw(path set_file_mode escape_filename);
use Fcntl ':flock';
use File::Copy ();

#--------------------------------------------------------------------------#
# Required by classes consuming this role
#--------------------------------------------------------------------------#

requires '_suffix';              # '.yml', '.json', etc.
requires '_thaw_from_handle';    # given handle, return session 'data' field
requires '_freeze_to_handle';    # given handle and data, serialize it


#--------------------------------------------------------------------------#
# Attributes and methods
#--------------------------------------------------------------------------#

has session_dir => (
    is      => 'ro',
    isa     => Str,
    default => sub { path( '.', 'sessions' ) },
);

sub BUILD {
    my $self = shift;

    if ( !-d $self->session_dir ) {
        mkdir $self->session_dir
          or croak "Unable to create session dir : "
          . $self->session_dir . ' : '
          . $!;
    }
}

sub _sessions {
    my ($self) = @_;
    my $sessions = [];

    opendir( my $dh, $self->session_dir )
      or croak "Unable to open directory " . $self->session_dir . " : $!";

    my $suffix = $self->_suffix;

    while ( my $file = readdir($dh) ) {
        next if $file eq '.' || $file eq '..';
        if ( $file =~ /(\w+)\Q$suffix\E/ ) {
            push @{$sessions}, $1;
        }
    }
    closedir($dh);

    return $sessions;
}

sub _retrieve {
    my ( $self, $id ) = @_;
    my $session_file = path( $self->session_dir, escape_filename($id) . $self->_suffix );

    croak "Invalid session ID: $id" unless -f $session_file;

    open my $fh, '+<', $session_file or die "Can't open '$session_file': $!\n";
    flock $fh, LOCK_SH or die "Can't lock file '$session_file': $!\n";
    my $data = $self->_thaw_from_handle($fh);
    close $fh or die "Can't close '$session_file': $!\n";

    return $data;
}

sub _change_id {
    my ($self, $old_id, $new_id) = @_;

    my $old_path =
      path($self->session_dir, escape_filename($old_id) . $self->_suffix);

    return if !-f $old_path;

    my $new_path =
      path($self->session_dir, escape_filename($new_id) . $self->_suffix);

    File::Copy::move($old_path, $new_path);
}

sub _destroy {
    my ( $self, $id ) = @_;
    my $session_file = path( $self->session_dir, escape_filename($id) . $self->_suffix );
    return if !-f $session_file;

    unlink $session_file;
}

sub _flush {
    my ( $self, $id, $data ) = @_;
    my $session_file = path( $self->session_dir, escape_filename($id) . $self->_suffix );

    open my $fh, '>', $session_file or die "Can't open '$session_file': $!\n";
    flock $fh, LOCK_EX or die "Can't lock file '$session_file': $!\n";
    seek $fh, 0, 0 or die "Can't seek in file '$session_file': $!\n";
    truncate $fh, 0 or die "Can't truncate file '$session_file': $!\n";
    set_file_mode($fh);
    $self->_freeze_to_handle( $fh, $data );
    close $fh or die "Can't close '$session_file': $!\n";

    return $data;
}

1;

__END__

=head1 DESCRIPTION

This is a specialized SessionFactory role for storing session
data in files.

This role manages the files.  Classes consuming it only need to handle
serialization and deserialization.

Classes consuming this must satisfy three requirements: C<_suffix>,
C<_freeze_to_handle> and C<_thaw_from_handle>.


    package Dancer2::Session::XYX;

    use Dancer2::Core::Types;
    use Moo;

    has _suffix => (
        is      => 'ro',
        isa     => Str,
        default => sub { '.xyz' },
    );

    with 'Dancer2::Core::Role::SessionFactory::File';

    sub _freeze_to_handle {
        my ($self, $fh, $data) = @_;

        # ... do whatever to get data into $fh

        return;
    }

    sub _thaw_from_handle {
        my ($self, $fh) = @_;
        my $data;

        # ... do whatever to get data from $fh

        return $data;
    }

    1;

=attr session_dir

Where to store the session files.  Defaults to "./sessions".

=cut
