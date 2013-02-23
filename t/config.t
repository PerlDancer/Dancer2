use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Carp 'croak';

use Dancer2::Core::Runner;
use Dancer2::Core::Role::Config;
use Dancer2::FileUtils qw/dirname path/;
use File::Spec;

my $runner = Dancer2::Core::Runner->new(caller => 'main');
my $location = File::Spec->rel2abs(path(dirname(__FILE__), 'config'));

{

    package Prod;
    use Moo;
    with 'Dancer2::Core::Role::Config';

    sub name {'Prod'}

    sub _build_environment     {'production'}
    sub _build_config_location {$location}
    sub default_config         { $runner->default_config }

    package Dev;
    use Moo;
    with 'Dancer2::Core::Role::Config';

    sub _build_environment     {'development'}
    sub _build_config_location {$location}
    sub default_config         { $runner->default_config }

    package Failure;
    use Moo;
    with 'Dancer2::Core::Role::Config';

    sub _build_environment     {'failure'}
    sub _build_config_location {$location}
    sub default_config         { $runner->default_config }

    package Staging;
    use Moo;
    with 'Dancer2::Core::Role::Config';

    sub _build_environment     {"staging"}
    sub _build_config_location {$location}
    sub default_config         { $runner->default_config }

}

my $d = Dev->new;
is_deeply $d->config_files,
  [path($location, 'config.yml'),],
  "config_files() only sees existing files";

my $f = Prod->new;
is $f->does('Dancer2::Core::Role::Config'), 1,
  "role Dancer2::Core::Role::Config is consumed";

is_deeply $f->config_files,
  [ path($location, 'config.yml'),
    path($location, 'environments', 'production.yml'),
  ],
  "config_files() works";

my $j = Staging->new;
is_deeply $j->config_files,
  [ path($location, 'config.yml'),
    path($location, 'environments', 'staging.json'),
  ],
  "config_files() does JSON too!";

note "bad YAML file";
my $fail = Failure->new;
is $fail->environment, 'failure';

is_deeply $fail->config_files,
  [ path($location, 'config.yml'),
    path($location, 'environments', 'failure.yml'),
  ],
  "config_files() works";

like(
    exception { $fail->config },
    qr{YAML}, 'Configuration file parsing failure',
);

note "config parsing";

is $f->config->{show_errors}, 0;
is $f->config->{main},        1;
is $f->config->{charset},     'utf-8', "normalized UTF-8 to utf-8";

ok($f->has_setting('charset'));
ok(!$f->has_setting('foobarbaz'));

note "default values";
is $f->setting('apphandler'),   'Standalone';
is $f->setting('content_type'), 'text/html';

like(
    exception { $f->_normalize_config({charset => 'BOGUS'}) },
    qr{Charset defined in configuration is wrong : couldn't identify 'BOGUS'},
    'Configuration file charset failure',
);

{

    package Foo;
    use Carp 'croak';
    sub foo { croak "foo" }
}

is $f->setting('traces'), 0;
unlike(exception { Foo->foo() }, qr{Foo::foo}, "traces are not enabled",);

$f->setting(traces => 1);
like(exception { Foo->foo() }, qr{Foo::foo}, "traces are enabled",);

done_testing;
