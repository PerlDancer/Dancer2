# plugin_import.t

use strict;
use warnings;
use Test::More;

{
    use Dancer;
    use t::lib::PluginWithImport;

    get '/test' => sub {
        dancer_plugin_with_import_keyword;
    };
}

use Dancer::Test;

response_content_is '/test', 'dancer_plugin_with_import_keyword',
  "the plugin exported its keyword";

is_deeply(
    t::lib::PluginWithImport->stuff,
    {'t::lib::PluginWithImport' => 'imported'},
    "the original import method of the plugin is still there"
);

done_testing;

