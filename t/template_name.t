use strict;
use warnings;
use File::Spec;
use File::Basename 'dirname';
use Test::More;

{
    package Foo;
    
    use Dancer 2.0;

    get '/template_name' => sub {
        return engine('template')->name;
    };
}

use Dancer::Test 'Foo';

response_content_is "/template_name", 'Tiny', 
    "template name";

done_testing;
