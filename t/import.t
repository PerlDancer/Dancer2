use strict;
use warnings;

use Test::More tests => 4;

BEGIN {
    # Set env vars to show these override imports
    $ENV{DANCER_APPHANDLER} = 'Standalone';
}

{

    package MyImportsApp;

    use Dancer2 port => 1234, apphandler => 'PSGI',
                views => '/some/path', logger => 'Null';

    get '/port' => sub {
        return setting 'port';
    };

    get '/apphandler' => sub {
        return setting 'apphandler';
    };

    get '/views' => sub {
        return setting 'views';
    };

    get '/log' => sub {
        # This app uses t/config.yml, which sets log to 'info'
        # setting from config overrides imported settings.
        return setting 'log';
    };
}

use Dancer2::Test apps => ['MyImportsApp'];

my $r = dancer_response GET => '/port';
is $r->content, 1234, 'port setting via import args';

$r = dancer_response GET => '/apphandler';
is $r->content, 'PSGI', 'apphandler setting: imported args override ENV defaults'; 

$r = dancer_response GET => '/views';
is $r->content, '/some/path', 'views setting via import args'; 

$r = dancer_response GET => '/log';
is $r->content, 'info', 'logger setting: config overrides over imported args';
