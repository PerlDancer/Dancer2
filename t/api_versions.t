use strict;
use warnings;

use Test::More tests => 2;

subtest 'dancer 1' => sub {
    plan tests => 3;

    package Foo;

    use Test::More;
    use Dancer 1;

    is dancer_app->api_version => 1, 'can be forced to api v1';

    is dancer_api_version() => 1, 'dancer_api_version';

    is ref( setting 'template' ) => 'Dancer::Template::Simple', 
        'v1 template is Simple';
};


subtest 'dancer 2' => sub {
    plan tests => 3;

    package Bar;

    use Test::More;
    use Dancer;

    is dancer_app->api_version => 2, 'default is 2';

    is dancer_api_version() => 2, 'dancer_api_version';

    is ref( setting 'template' ) => 'Dancer::Template::Tiny', 
        'v2 template is Tiny';
}


