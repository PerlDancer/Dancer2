package t::lib::Hookee;

use Dancer2::Plugin;

register_hook 'start_hookee', 'stop_hookee';
register_hook 'third_hook';

register some_keyword => sub {
    execute_hook('start_hookee');
};

register some_other => sub {
    execute_hook('third_hook');
};

register_plugin for_versions => [2];

1;
