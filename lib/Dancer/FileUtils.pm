# ABSTRACT: TODO

package Dancer::FileUtils;

use strict;
use warnings;

use File::Basename ();
use File::Spec;
use IO::File;
use IO::Handle;
use Carp;
use Cwd 'realpath';

use base 'Exporter';
use vars '@EXPORT_OK';

@EXPORT_OK = qw(
    dirname open_file path read_file_content read_glob_content
    path_or_empty set_file_mode normalize_path
);

# path should not verify paths
# just normalize
sub path {
    my @parts = @_;
    my $path  = File::Spec->catfile(@parts);

    return normalize_path($path);
}

sub path_or_empty {
    my @parts = @_;
    my $path  = path(@parts);

    # return empty if it doesn't exist
    return -e $path ? $path : '';
}

sub dirname { File::Basename::dirname(@_) }

sub set_file_mode {
    my $fh = shift;
    my $charset = 'utf-8';
    binmode $fh, ":encoding($charset)";
    return $fh;
}

sub open_file {
    my ( $mode, $filename ) = @_;

    my $fh = IO::File->new();
    unless ($fh->open($filename, $mode)) {
        croak "Can't open '$filename' using mode '$mode'";
    }
    my $io = IO::Handle->new();
    $io->fdopen($fh->fileno, $mode);
    $io->blocking(0);

    return set_file_mode($io);
}

sub read_file_content {
    my $file = shift or return;
    my $fh   = open_file( '<', $file );

    return wantarray              ?
           read_glob_content($fh) :
           scalar read_glob_content($fh);
}

sub read_glob_content {
    my $fh = shift;
    binmode $fh;

    my @content = <$fh>;
    $fh->close;

    return wantarray ? @content : join '', @content;
}

sub normalize_path {
    # this is a revised version of what is described in
    # http://www.linuxjournal.com/content/normalizing-path-names-bash
    # by Mitch Frazier
    my $path     = shift or return;
    my $seqregex = qr{
        [^/]*  # anything without a slash
        /\.\./ # that is accompanied by two dots as such
    }x;

    $path =~ s{/\./}{/}g;
    $path =~ s{$seqregex}{}g;
    $path =~ s{$seqregex}{};

    return $path;
}

1;

__END__

=pod

=head1 NAME

Dancer::FileUtils - helper providing file utilities

=head1 SYNOPSIS

    use Dancer::FileUtils qw/dirname path/;

    # for 'path/to/file'
    my $dir  = dirname($path); # returns 'path/to'
    my $path = path($path);    # returns '/abs/path/to/file'


    use Dancer::FileUtils qw/path read_file_content/;

    my $content = read_file_content( path( 'folder', 'folder', 'file' ) );
    my @content = read_file_content( path( 'folder', 'folder', 'file' ) );

    use Dancer::FileUtils qw/read_glob_content set_file_mode/;

    open my $fh, '<', $file or die "$!\n";
    set_file_mode($fh);
    my @content = read_file_content($fh);
    my $content = read_file_content($fh);


=head1 DESCRIPTION

Dancer::FileUtils includes a few file related utilities related that Dancer
uses internally. Developers may use it instead of writing their own
file reading subroutines or using additional modules.

=head1 SUBROUTINES/METHODS

=head2 dirname

    use Dancer::FileUtils 'dirname';

    my $dir = dirname($path);

Exposes L<File::Basename>'s I<dirname>, to allow fetching a directory name from
a path. On most OS, returns all but last level of file path. See
L<File::Basename> for details.

=head2 open_file

    use Dancer::FileUtils 'open_file';
    my $fh = open_file('<', $file) or die $message;

Calls open and returns a filehandle. Takes in account the 'charset' setting
from Dancer's configuration to open the file in the proper encoding (or
defaults to utf-8 if setting not present).

=head2 path

    use Dancer::FileUtils 'path';

    my $path = path( 'folder', 'folder', 'filename');

Provides comfortable path resolving, internally using L<File::Spec>.

=head2 read_file_content

    use Dancer::FileUtils 'read_file_content';

    my @content = read_file_content($file);
    my $content = read_file_content($file);

Returns either the content of a file (whose filename is the input), I<undef>
if the file could not be opened.

In array context it returns each line (as defined by $/) as a seperate element;
in scalar context returns the entire contents of the file.

=head2 read_glob_content

    use Dancer::FileUtils 'read_glob_content';

    open my $fh, '<', $file or die "$!\n";
    my @content = read_glob_content($fh);
    my $content = read_glob_content($fh);

Same as I<read_file_content>, only it accepts a file handle. Returns the
content and B<closes the file handle>.

=head2 set_file_mode

    use Dancer::FileUtils 'set_file_mode';

    set_file_mode($fh);

Applies charset setting from Dancer's configuration. Defaults to utf-8 if no
charset setting.

=head1 EXPORT

Nothing by default. You can provide a list of subroutines to import.

=head1 AUTHOR

Alexis Sukrieh

=head1 LICENSE AND COPYRIGHT

Copyright 2009-2011 Alexis Sukrieh.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
