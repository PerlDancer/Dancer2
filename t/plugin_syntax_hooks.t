use strict;
use warnings;
use Test::More import => ['!pass'];
use Dancer2::Test;

my $counter = 0;

{
    use Dancer2;
    use t::lib::Hookee;

    hook 'third_hook' => sub {
        var(hook => 'third hook');
    };

    hook 'start_hookee' => sub {
        'hook for plugin';
    };

    get '/hook_with_var' => sub {
        some_other();
        is var('hook') => 'third hook', "Vars preserved from hooks";
    };

    get '/hooks_plugin' => sub {
        $counter++;
        some_keyword();
    };

}

is $counter, 0, "the hook has not been executed";
my $r = dancer_response(GET => '/hooks_plugin');
is($r->content, 'hook for plugin', '... route is rendered');
is $counter, 1, "... and the hook has been executed exactly once";

dancer_response(GET => '/hook_with_var');

done_testing();
