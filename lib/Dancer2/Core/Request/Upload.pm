package Dancer2::Core::Request::Upload;
# ABSTRACT: Class representing file upload requests

use Moo;

use Carp;
use Path::Tiny ();
use File::Copy ();
use Module::Runtime 'require_module';

use Dancer2::Core::Types;

has filename => (
    is  => 'ro',
    isa => Str,
);

has tempname => (
    is  => 'ro',
    isa => Str,
);

has headers => (
    is  => 'ro',
    isa => HashRef,
);

has size => (
    is  => 'ro',
    isa => Num,
);

sub file_handle {
    my ($self) = @_;
    return $self->{_fh} if defined $self->{_fh};
    $self->{_fh} = Path::Tiny::path( $self->tempname )->openr_raw;
}

sub copy_to {
    my ( $self, $target ) = @_;
    File::Copy::copy( $self->tempname, $target );
}

sub link_to {
    my ( $self, $target ) = @_;
    CORE::link( $self->tempname, $target );
}

sub content {
    my ( $self, $layer ) = @_;
    return $self->{_content}
      if defined $self->{_content};

    $layer = ':raw' unless $layer;

    my $content = undef;
    my $handle  = $self->file_handle;

    binmode( $handle, $layer );

    while ( $handle->read( my $buffer, 8192 ) ) {
        $content .= $buffer;
    }

    $self->{_content} = $content;
}

sub basename {
    my ($self) = @_;
    require_module('File::Basename');
    File::Basename::basename( $self->filename );
}

sub type {
    my $self = shift;
    return $self->headers->{'Content-Type'};
}

1;

__END__

=head1 DESCRIPTION

This class implements a representation of file uploads for Dancer2.
These objects are accessible within route handlers via the request->uploads
keyword. See L<Dancer2::Core::Request> for details.


=attr filename

Filename as sent by client. optional. May not be undef.

=method my $filename=$upload->filename;

Returns the filename (full path) as sent by the client.

=attr tempname

The name of the temporary file the data has been saved to. Optional. May not be undef.

=method my $tempname=$upload->tempname;

Returns the name of the temporary file the data has been saved to.

For example, in directory /tmp, and given a random name, with no file extension.

=attr headers

A hash ref of the headers associated with this upload. optional. is read-write and a HashRef.

=method my $href=$upload->headers;

Returns a hashRef of the headers associated with this upload.

=attr size

The size of the upload, in bytes. Optional.

=method my $fh=$upload->file_handle;

Returns a read-only file handle on the temporary file.

=method $upload->copy_to('/path/to/target')

Copies the temporary file using File::Copy. Returns true for success,
false for failure.

=method $upload->link_to('/path/to/target');

Creates a hard link to the temporary file. Returns true for success,
false for failure.

=method my $content=$upload->content;

Returns a scalar containing the contents of the temporary file.

=method my $basename=$upload->basename;

Returns basename for "filename".

=method $upload->type

Returns the Content-Type of this upload.

=head1 SEE ALSO

L<Dancer2>

=cut
