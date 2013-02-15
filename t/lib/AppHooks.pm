package t::lib::AppHooks;

use Dancer ':syntax';
use t::lib::PluginHook;

setting appdir => 't';
setting(engines =>
  {session => { YAML => {session_dir => 't/sessions'}}});
setting session  => 'YAML';

setting( plugins => {
    't::lib::PluginHook' => { 
        test_separation => 'Set by t::lib::AppHooks'
    } 
} );

get '/next' => sub {    
    return template 'PluginHooks';
};

get '/' => sub {
    flash 'This is the flashed message';
    return redirect '/next';
};

true;
