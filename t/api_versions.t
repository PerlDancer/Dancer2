use strict;
use warnings;

use Test::More tests => 4;

{
    package Foo;

    use Test::More;
    use Dancer;

    is dancer_app->api_version => 1, 'default is api v1';

    is ref( setting 'template' ) => 'Dancer::Template::Simple', 
        'v1 template is Simple';
}

{
    package Bar;

    use Test::More;
    use Dancer 2;  # New and Improved!

    is dancer_app->api_version => 2, 'asked for 2 explicitly';

    is ref( setting 'template' ) => 'Dancer::Template::Tiny', 
        'v2 template is Tiny';
}


