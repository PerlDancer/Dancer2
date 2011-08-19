use Test::More tests => 8;
use strict;
use warnings;
use File::Spec;
use File::Temp 0.22;

use Dancer::FileUtils qw/read_file_content path_or_empty/;

sub write_file {
    my ($file, $content) = @_;

    open CONF, '>', $file or die "cannot write file $file : $!";
    print CONF $content;
    close CONF;
}

eval { Dancer::FileUtils::open_file('<', '/slfkjsdlkfjsdlf') };
like $@, qr{/slfkjsdlkfjsdlf' using mode '<'};

my $content = Dancer::FileUtils::read_file_content();
is $content, undef;

is Dancer::FileUtils::normalize_path(), undef;

my $p = Dancer::FileUtils::dirname('/somewhere');
is $p, '/';

my $tmp = File::Temp->new();
write_file($tmp, "one$/two");

$content = read_file_content($tmp);
ok $content = "one$/two";

my @content = read_file_content($tmp);
ok $content[0] eq "one$/" && $content[1] eq 'two';

# returns UNDEF on non-existant path
my $path = 'bla/blah';
if (! -e $path) {
    is(
        path_or_empty($path),
        '',
        'path_or_empty on non-existent path',
    );
}

is(path_or_empty('/tmp'), '/tmp');
