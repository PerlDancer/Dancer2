package t::lib::AppHooks;

use Dancer ':syntax';
use t::lib::PluginHook;

set appdir => 't';
set engines =>
  { session => { YAML => {session_dir => 't/sessions'} } };
set session   => 'YAML';
set template  => 'tiny';

set plugins => {
    't::lib::PluginHook' => { 
        test_separation => 'Set by t::lib::AppHooks'
    } 
};

get '/next' => sub {
    return template 'PluginHooks';
};

get '/' => sub {
    flash 'This is the flashed message';
    return redirect '/next';
};

true;
