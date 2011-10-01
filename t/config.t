use strict;
use warnings;
use Test::More;
use Carp 'croak';

use Dancer::Core::Runner;
use Dancer::Core::Role::Config;
use Dancer::FileUtils qw/dirname path/;
use File::Spec;

my $runner = Dancer::Core::Runner->new(caller => 'main');
my $location = File::Spec->rel2abs(path(dirname(__FILE__), 'config'));

{
    package Prod;
    use Moo;
    with 'Dancer::Core::Role::Config';

    sub get_environment { "production" }
    sub config_location { $location }
    sub default_config { $runner->default_config }

    package Dev;
    use Moo;
    with 'Dancer::Core::Role::Config';

    sub get_environment { "development" }
    sub config_location { $location }
    sub default_config { $runner->default_config }

    package Failure;
    use Moo;
    with 'Dancer::Core::Role::Config';

    sub get_environment { "failure" }
    sub config_location { $location }
    sub default_config { $runner->default_config }

}

my $d = Dev->new;
is_deeply [$d->config_files], 
    [
     path($location, 'config.yml'), 
    ],
    "config_files() only sees existing files";

my $f = Prod->new;
is $f->does('Dancer::Core::Role::Config'), 1,
    "role Dancer::Core::Role::Config is consumed";

is_deeply [$f->config_files], 
    [
     path($location, 'config.yml'), 
     path($location, 'environments', 'production.yml'),
    ],
    "config_files() works";

note "bad YAML file";
my $fail = Failure->new;
is $fail->get_environment, 'failure';

is_deeply [$fail->config_files], 
    [
     path($location, 'config.yml'), 
     path($location, 'environments', 'failure.yml'),
    ],
    "config_files() works";


eval { $fail->config };
like $@, qr{Unable to parse the configuration file};

note "config parsing";

is $f->config->{show_errors}, 0;
is $f->config->{main}, 1;
is $f->config->{charset}, 'utf-8', 
    "normalized UTF-8 to utf-8";

ok($f->has_setting('charset'));
ok(!$f->has_setting('foobarbaz'));

note "default values";
is $f->setting('apphandler'), 'Standalone';
is $f->setting('content_type'), 'text/html';

eval { $f->_normalize_config({charset => 'BOGUS'}) };
like $@, qr{Charset defined in configuration is wrong : couldn't identify 'BOGUS'};

{ 
    package Foo;
    use Carp 'croak';
    sub foo { croak "foo" };
}

is $f->setting('traces'), 0;
eval { Foo->foo() };
unlike $@, qr{Foo::foo}, 
    "traces are not enabled";

$f->setting(traces => 1);
eval { Foo->foo() };
like $@, qr{Foo::foo},
    "traces are enabled";

done_testing;
