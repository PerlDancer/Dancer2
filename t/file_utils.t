use strict;
use warnings;
use Test::More tests => 11;
use Test::Fatal;
use File::Spec;
BEGIN { @File::Spec::ISA = ("File::Spec::Unix") }
use File::Temp 0.22;

use Dancer2::FileUtils qw/read_file_content path_or_empty path/;

sub write_file {
    my ($file, $content) = @_;

    open CONF, '>', $file or die "cannot write file $file : $!";
    binmode CONF;
    print CONF $content;
    close CONF;
}

sub hexe {
    my $s = shift;
    $s =~ s/([\x00-\x1F])/sprintf('%#x',ord($1))/eg;
    return $s;
}

like(
    exception { Dancer2::FileUtils::open_file('<', '/slfkjsdlkfjsdlf') },
    qr{/slfkjsdlkfjsdlf' using mode '<'},
    'Failure opening nonexistent file',
);

my $content = Dancer2::FileUtils::read_file_content();
is $content, undef;

is Dancer2::FileUtils::normalize_path(), undef;

my $p = Dancer2::FileUtils::dirname('/somewhere');
is $p, '/';

my $tmp = File::Temp->new();
write_file($tmp, "one$/two");

$content = read_file_content($tmp);
is hexe($content), hexe("one$/two");

my @content = read_file_content($tmp);
is hexe($content[0]), hexe("one$/");
is $content[1], 'two';

# returns UNDEF on non-existant path
my $path = 'bla/blah';
if (!-e $path) {
    is(path_or_empty($path), '', 'path_or_empty on non-existent path',);
}

my $tmpdir = File::Temp->newdir;
is(path_or_empty($tmpdir), $tmpdir, 'path_or_empty on an existing path' );

#slightly tricky paths on different platforms
is(path('/', 'b', '/c'), '/b//c', 'path /,b,/c -> /b//c');
is(path('/', '/b',), '/b', 'path /, /b -> /b');
