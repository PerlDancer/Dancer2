use Test::More import => ['!pass'];
use strict;
use warnings;
use File::Spec;
use Dancer::FileUtils qw/read_file_content path_or_empty/;
use File::Temp 0.22;

sub write_file {
    my ($file, $content) = @_;

    open CONF, '>', $file or die "cannot write file $file : $!";
    print CONF $content;
    close CONF;
}

plan tests => 3;

my $tmp = File::Temp->new();
write_file($tmp, "one$/two");

my $content = read_file_content($tmp);
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
