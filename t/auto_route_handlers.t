use strict;
use warnings;
use Test::More;

use File::Spec;
use File::Basename 'dirname';
use Dancer::FileUtils 'path';
use Dancer::Core::App;

my $local_dir = File::Spec->rel2abs(dirname(__FILE__));

my $app = Dancer::Core::App->new(
    name => 'foo', 
    location => $local_dir,
);

is_deeply $app->config->{route_handlers},
 {
     File => { public_dir => path($local_dir, 'public'), },
     AutoPage => 1,
 }, "got the default route handlers config";

# TODO test the route handlers 

$app->finish;

done_testing;
