use strict;
use warnings;
use utf8;

use Test::More tests => 25;
use Test::Fatal;
use File::Spec;
BEGIN { @File::Spec::ISA = ("File::Spec::Unix") }
use File::Temp 0.22;

use Dancer2::FileUtils qw/read_file_content path_or_empty path/;

sub write_file {
    my ( $file, $content ) = @_;

    open my $fh, '>', $file or die "cannot write file $file : $!";
    binmode $fh, ':encoding(utf-8)';
    print $fh $content;
    close $fh;
}

sub hexe {
    my $s = shift;
    $s =~ s/([\x00-\x1F])/sprintf('%#x',ord($1))/eg;
    return $s;
}

like(
    exception { Dancer2::FileUtils::open_file( '<', '/slfkjsdlkfjsdlf' ) },
    qr{/slfkjsdlkfjsdlf' using mode '<': \w+},
    'Failure opening nonexistent file',
);

my $content = Dancer2::FileUtils::read_file_content();
is $content, undef;

my $paths = [
   [ undef          => 'undef' ],
   [ '/foo/./bar/'  => '/foo/bar/' ],
   [ '/foo/../bar' => '/bar' ],
   [ '/foo/bar/..'  => '/foo/' ],
   [ '/a/b/c/d/A/B/C' => '/a/b/c/d/A/B/C' ],
   [ '/a/b/c/d/../A/B/C' => '/a/b/c/A/B/C' ],
   [ '/a/b/c/d/../../A/B/C' => '/a/b/A/B/C' ],
   [ '/a/b/c/d/../../../A/B/C' => '/a/A/B/C' ],
   [ '/a/b/c/d/../../../../A/B/C' => '/A/B/C' ], 
];

for my $case ( @$paths ) {
    is Dancer2::FileUtils::normalize_path( $case->[0] ), $case->[1];
}

my $p = Dancer2::FileUtils::dirname('/somewhere');
is $p, '/';

my $tmp = File::Temp->new();
my $two = "²❷";
write_file( $tmp, "one$/$two" );

$content = read_file_content($tmp);
is hexe($content), hexe("one$/$two");

my @content = read_file_content($tmp);
is hexe( $content[0] ), hexe("one$/");
is $content[1], "$two";

# returns UNDEF on non-existant path
my $path = 'bla/blah';
if ( !-e $path ) {
    is( path_or_empty($path), '', 'path_or_empty on non-existent path', );
}

my $tmpdir = File::Temp->newdir;
is( path_or_empty($tmpdir), $tmpdir, 'path_or_empty on an existing path' );

#slightly tricky paths on different platforms
is( path( '/', 'b', '/c' ), '/b//c', 'path /,b,/c -> /b//c' );
is( path( '/', '/b', ), '/b', 'path /, /b -> /b' );

note "escape_filename"; {
    my $names = [
        [ undef      => 'undef' ],
        [ 'abcdef'   => 'abcdef' ],
        [ 'ab++ef'   => 'ab+2b+2bef' ],
        [ 'a/../b.txt'   => 'a+2f+2e+2e+2fb+2etxt' ],
        [ "test\0\0" => 'test+00+00' ],
        [ 'test☠☠☠'  => 'test+2620+2620+2620' ],
    ];

    for my $case ( @$names ) {
      is Dancer2::FileUtils::escape_filename( $case->[0] ), $case->[1];
    }
}
