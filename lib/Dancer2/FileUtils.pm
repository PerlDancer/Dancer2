package Dancer2::FileUtils;
# ABSTRACT: File utility helpers

use strict;
use warnings;

use Path::Tiny ();
use Carp;

use Exporter 'import';
our @EXPORT_OK = qw(
  dirname open_file path read_file_content read_glob_content
  path_or_empty set_file_mode escape_filename
);


sub path {
    my @parts = @_;
    return Path::Tiny::path(@parts)->stringify;
}

sub path_or_empty {
    my @parts = @_;
    my $path  = Path::Tiny::path(@parts);

    # return empty if it doesn't exist
    return $path->exists ? $path->stringify : '';
}

sub dirname { return Path::Tiny::path(@_)->parent->stringify; }

sub set_file_mode {
    my $fh      = shift;
    my $charset = 'UTF-8';
    binmode $fh, ":encoding($charset)";
    return $fh;
}

sub open_file {
    my ( $mode, $filename ) = @_;

    return Path::Tiny::path($filename)->filehandle(
        $mode, ':encoding(UTF-8)',
    );
}

sub read_file_content {
    my $file = shift or return;
    my $fh = open_file( '<', $file );

    return wantarray
      ? read_glob_content($fh)
      : scalar read_glob_content($fh);
}

sub read_glob_content {
    my $fh = shift;

    my @content = <$fh>;
    close $fh;

    return wantarray ? @content : join '', @content;
}

sub escape_filename {
    my $filename = shift or return;

    # based on escaping used in CHI::Driver. Our use-case is one-way,
    # so we allow utf8 chars to be escaped, but NEVER do the inverse
    # operation.
    $filename =~ s/([^A-Za-z0-9_\=\-\~])/sprintf("+%02x", ord($1))/ge;
    return $filename;
}

1;

__END__

=head1 DESCRIPTION

Dancer2::FileUtils includes a few file related utilities that Dancer2
uses internally. Developers may use it instead of writing their own
file reading subroutines or using additional modules.

=head1 SYNOPSIS

    use Dancer2::FileUtils qw/dirname path path_or_empty/;

    # for 'path/to/file'
    my $dir  = dirname($path); # returns 'path/to'
    my $path = path($path);    # returns '/abs/path/to/file'
    my $path = path_or_empty($path);    # returns '' if file doesn't exist


    use Dancer2::FileUtils qw/path read_file_content/;

    my $content = read_file_content( path( 'folder', 'folder', 'file' ) );
    my @content = read_file_content( path( 'folder', 'folder', 'file' ) );


    use Dancer2::FileUtils qw/read_glob_content set_file_mode/;

    open my $fh, '<', $file or die "$!\n";
    set_file_mode($fh);
    my @content = read_glob_content($fh);
    my $content = read_glob_content($fh);


    use Dancer2::FileUtils qw/open_file/;

    my $fh = open_file('<', $file) or die $message;


    use Dancer2::FileUtils 'set_file_mode';

    set_file_mode($fh);

=head1 EXPORT

Nothing by default. You can provide a list of subroutines to import.

=func my $path = path( 'folder', 'folder', 'filename');

Calls L<Path::Tiny>'s C<< path(...)->stringify >> path parts.
Better if you use C<Path::Tiny::path(@parts)> directly instead.

If you want to normalize the path (for existing path), use:

    Path::Tiny::path(@parts)->realpath->stringify;

=func my $path = path_or_empty('folder, 'folder','filename');

Like path, but returns '' if path doesn't exist.

=func dirname

    use Dancer2::FileUtils 'dirname';
    my $dir = dirname($path);

    # Same thing:
    use Path::Tiny qw< path >;
    my $dir       = path($path)->parent;
    my $as_string = $dir->stringify;

Fetches the directory name of a path
On most OS, returns all but last level of file path. See
L<Path::Tiny> for details.

=func set_file_mode($fh);

    use Dancer2::FileUtils 'set_file_mode';

    set_file_mode($fh);

Applies charset setting from Dancer2's configuration. Defaults to utf-8 if no
charset setting.

=func my $fh = open_file('<', $file) or die $message;

    use Dancer2::FileUtils 'open_file';
    my $fh = open_file('<', $file) or die $message;

Calls open and returns a filehandle. Takes in account the 'charset' setting
from Dancer2's configuration to open the file in the proper encoding (or
defaults to utf-8 if setting not present).

=func my $content = read_file_content($file);

    use Dancer2::FileUtils 'read_file_content';

    my @content = read_file_content($file);
    my $content = read_file_content($file);

Returns either the content of a file (whose filename is the input), or I<undef>
if the file could not be opened.

In array context it returns each line (as defined by $/) as a separate element;
in scalar context returns the entire contents of the file.

=func my $content = read_glob_content($fh);

    use Dancer2::FileUtils 'read_glob_content';

    open my $fh, '<', $file or die "$!\n";
    binmode $fh, ':encoding(utf-8)';
    my @content = read_glob_content($fh);
    my $content = read_glob_content($fh);

Similar to I<read_file_content>, only it accepts a file handle. It is
assumed that the appropriate PerlIO layers are applied to the file handle.
Returns the content and B<closes the file handle>.

=func my $escaped_filename = escape_filename( $filename );

Escapes characters in a filename that may alter a path when concatenated.

  use Dancer2::FileUtils 'escape_filename';

  my $safe = escape_filename( "a/../b.txt" ); # a+2f+2e+2e+2fb+2etxt

=cut
