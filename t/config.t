use strict;
use warnings;
use Test::More;

use Dancer::Core::Role::Config;
use Dancer::FileUtils qw/dirname path/;
use File::Spec;

my $location = File::Spec->rel2abs(path(dirname(__FILE__), 'config'));

{
    package Foo;
    use Moo;
    with 'Dancer::Core::Role::Config';

    sub get_environment { "production" }
    sub config_location { $location }
}

my $f = Foo->new;
isa_ok $f, 'Foo';
is $f->does('Dancer::Core::Role::Config'), 1,
    "role Dancer::Core::Role::Config is consumed";

is_deeply [$f->config_files], 
    [
     path($location, 'config.yml'), 
     path($location, 'environments', 'production.yml'),
    ],
    "config_files() works";

is $f->config->{show_errors}, 0;
is $f->config->{main}, 1;

done_testing;
