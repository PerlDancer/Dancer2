use strict;
use warnings;

use Test::More tests => 4;

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

    get '/logger' => sub {
        return setting 'logger';
    };
}

use Dancer2::Test apps => ['MyImportsApp'];

my $r = dancer_response GET => '/port';
is $r->content, 1234, 'port setting via import args';

$r = dancer_response GET => '/apphandler';
is $r->content, 'PSGI', 'apphandler setting via import args'; 

$r = dancer_response GET => '/views';
is $r->content, '/some/path', 'views setting via import args'; 

$r = dancer_response GET => '/logger';
is $r->content, 'Null', 'logger setting via import args'; 
