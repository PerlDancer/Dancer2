BEGIN {
  package Dancer2::Plugin::Plugin1;
  use Dancer2::Plugin;

    has one => (
      is => 'ro',
      default => sub { 'uno' },
      plugin_keyword => 1,
    );

    plugin_hooks 'un';
}

BEGIN {
  package Dancer2::Plugin::Plugin2;
  use Dancer2::Plugin;

    has two => (
      is => 'ro',
      default => sub { 'dos' },
      plugin_keyword => 1,
    );

    plugin_hooks 'deux';

}

use Test::More;

my %tests = (
    'Plugin1' => { keywords => [ 'one' ], hooks => [ 'un' ] },
    'Plugin2' => { keywords => [ 'two' ], hooks => [ 'deux' ] },
);

subtest $_ => sub {
    my $plugin = join '::', 'Dancer2', 'Plugin', $_;

    is_deeply [ keys %{ $plugin->keywords } ] => $tests{$_}{keywords}, 'keywords';
    is_deeply [ @{ $plugin->ClassHooks } ] => $tests{$_}{hooks}, 'hooks';

} for sort keys %tests;


subtest app_side => sub {
    package MyApp;

    use Dancer2 '!pass';
    use Dancer2::Plugin::Plugin1;
    use Dancer2::Plugin::Plugin2;

    use Test::More;

    Test::More::is one() => 'uno', 'from plugin1';
    Test::More::is two() => 'dos', 'from plugin2';

    is_deeply { map { ref $_ => [ keys %{ $_->hooks } ] } @{ app()->plugins } },
        {
            'Dancer2::Plugin::Plugin1' => [ 'plugin.plugin1.un' ],
            'Dancer2::Plugin::Plugin2' => [ 'plugin.plugin2.deux' ],
        };
};

done_testing();
