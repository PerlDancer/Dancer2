package t::lib::PluginHook;

use Dancer::Plugin;
use strict;
use warnings;

setting( plugins => {
    't::lib::PluginHook' => { 
        test_separation => 'Set by t::lib::PluginHook'
    } 
} );

register flash => sub {
    my $dsl = shift;
    my ($value) = @_;

    $dsl->session('_my_flash', $value) if $value;
    $value = $dsl->session('value');
    return $value;
};

hook before_template_render => sub {
    my $dsl    = shift;
    my $tokens = shift;
    $tokens->{flash}      = session('_my_flash');
    $tokens->{config_msg} = 
        $dsl->setting('plugins')->{'t::lib::PluginHook'}->{test_separation};
};
    
register_plugin for_versions => [1, 2];

1;
