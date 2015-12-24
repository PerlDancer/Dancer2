use strict;
use warnings;

use Test::More;

BEGIN {
    package 
        Dancer2::Plugin::Foo;

    use Dancer2::Plugin;

    plugin_keywords 'foo', 'bar', 'baz';

    sub foo :PluginKeyword {
        $_[0]->config->{oops};
    }

    sub bar :PluginKeyword {
        plugin_setting()->{oops};
    }

    sub baz :PluginKeyword {
        _indirect();
    }

    sub indirect {
        plugin_setting()->{oops};
    }
}

{
    package 
        Alpha;

    use Dancer2 '!pass';
    use Test::More;

    dancer_app->config->{plugins}{Foo}{oops} = 'alpha';

    use Dancer2::Plugin::Foo;

    is foo() => 'alpha', 'foo';
    is bar() => 'alpha', 'bar';
    is baz() => 'alpha', 'baz';

}
{
    package 
        Beta;

    use Dancer2 '!pass';
    use Test::More;

    dancer_app->config->{plugins}{Foo}{oops} = 'beta';

    use Dancer2::Plugin::Foo;

    is foo() => 'beta', 'foo';
    is bar() => 'beta', 'bar';
    is baz() => 'beta', 'baz';
}

done_testing();
