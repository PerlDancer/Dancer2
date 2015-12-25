use strict;
use warnings;

use Test::More;

BEGIN {
    package 
        Dancer2::Plugin::Foo;

    use Dancer2::Plugin;

    plugin_keywords 'from_config', 'from_plugin_setting', 'from_indirect';

    sub from_config :PluginKeyword {
        $_[0]->config->{oops};
    }

    sub from_plugin_setting :PluginKeyword {
        plugin_setting()->{oops};
    }

    sub from_indirect :PluginKeyword {
        _indirect();
    }

    sub _indirect {
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

    is from_config()         => 'alpha', 'alpha from config';
    is from_plugin_setting() => 'alpha', 'alpha from plugin_setting';
    is from_indirect()       => 'alpha', 'alpha from indirect';

}
{
    package 
        Beta;

    use Dancer2 '!pass';
    use Test::More;

    dancer_app->config->{plugins}{Foo}{oops} = 'beta';

    use Dancer2::Plugin::Foo;

    is from_config()         => 'beta', 'beta from config';
    is from_plugin_setting() => 'beta', 'beta from plugin_setting';
    is from_indirect()       => 'beta', 'beta from indirect';
}

done_testing();
