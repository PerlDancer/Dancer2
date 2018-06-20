use strict;
use warnings;
use Test::More;
use Dancer2::Core::Hook;
use Plack::Test;
use HTTP::Request::Common;

use File::Spec;
use File::Basename 'dirname';

eval { require Template; Template->import(); 1 }
  or plan skip_all => 'Template::Toolkit probably missing.';

use_ok('Dancer2::Template::TemplateToolkit');

my $views =
  File::Spec->rel2abs( File::Spec->catfile( dirname(__FILE__), 'views' ) );

my $tt = Dancer2::Template::TemplateToolkit->new(
    views  => $views,
    layout => 'main.tt',
    layout_dir => 'layouts',
);

isa_ok $tt, 'Dancer2::Template::TemplateToolkit';
ok $tt->does('Dancer2::Core::Role::Template');

$tt->add_hook(
    Dancer2::Core::Hook->new(
        name => 'engine.template.before_render',
        code => sub {
            my $tokens = shift;
            $tokens->{before_template_render} = 1;
        },
    )
);

$tt->add_hook(
    Dancer2::Core::Hook->new(
        name => 'engine.template.before_layout_render',
        code => sub {
            my $tokens  = shift;
            my $content = shift;

            $tokens->{before_layout_render} = 1;
            $$content .= "\ncontent added in before_layout_render";
        },
    )
);

$tt->add_hook(
    Dancer2::Core::Hook->new(
        name => 'engine.template.after_layout_render',
        code => sub {
            my $content = shift;
            $$content .= "\ncontent added in after_layout_render";
        },
    )
);

$tt->add_hook(
    Dancer2::Core::Hook->new(
        name => 'engine.template.after_render',
        code => sub {
            my $content = shift;
            $$content .= 'content added in after_template_render';
        },
    )
);

{
    package Bar;
    use Dancer2;

    # set template engine for first app
    Dancer2->runner->apps->[0]->set_template_engine($tt);

    get '/' => sub { template index => { var => 42 } };

    # Call template as a global keyword
    my $global= template( index => { var => 21 } );
    get '/global' => sub { $global };
}

subtest 'template hooks' => sub {
    my $space  = " ";
    my $result = "layout top
var = 42
before_layout_render = 1
---
[index]
var = 42

before_layout_render =$space
before_template_render = 1
content added in after_template_render
content added in before_layout_render
---
layout bottom

content added in after_layout_render";

    my $test = Plack::Test->create( Bar->to_app );
    my $res = $test->request( GET '/' );
    is $res->content, $result, '[GET /] Correct content with template hooks';

    $result =~ s/42/21/g;
    $res = $test->request( GET '/global' );
    is $res->content, $result, '[GET /global] Correct content with template hooks';
};

{

    package Foo;

    use Dancer2;
    set views => '/this/is/our/path';

    get '/default_views'          => sub { set 'views' };
    get '/set_views_via_settings' => sub { set views => '/other/path' };
    get '/get_views_via_settings' => sub { set 'views' };

    get '/default_layout_dir'          => sub { app->template_engine->layout_dir };
    get '/set_layout_dir_via_settings' => sub { set layout_dir => 'alt_layout' };
    get '/get_layout_dir_via_settings' => sub { set 'layout_dir' };

}

subtest "modify views - absolute paths" => sub {

    my $test = Plack::Test->create( Foo->to_app );

    is(
        $test->request( GET '/default_views' )->content,
        '/this/is/our/path',
        '[GET /default_views] Correct content',
    );

    # trigger a test via a route
    $test->request( GET '/set_views_via_settings' );

    is(
        $test->request( GET '/get_views_via_settings' )->content,
        '/other/path',
        '[GET /get_views_via_settings] Correct content',
    );
};

subtest "modify layout_dir" => sub {
    my $test = Plack::Test->create( Foo->to_app );

    is(
        $test->request( GET '/default_layout_dir' )->content,
        'layouts',
        '[GET /default_layout_dir] Correct layout dir',
    );

    # trigger a test via a route
    $test->request( GET '/set_layout_dir_via_settings' );

    is(
        $test->request( GET '/get_layout_dir_via_settings' )->content,
        'alt_layout',
        '[GET /get_layout_dir_via_settings] Correct content',
    );
};

{
    package Baz;
    use Dancer2;

    set template => 'template_toolkit';

    get '/set_views/**' => sub {
        my ($view) = splat;
        set views => join('/', @$view );
    };

    get '/:file' => sub {
        template param('file');
    };
}

subtest "modify views propagates to TT2 via dynamic INCLUDE_PATH" => sub {

    my $test = Plack::Test->create( Baz->to_app );

    my $res = $test->request( GET '/index' );
    is $res->code, 200, 'got template from views';

    # Change views - this is an existing test corpus..
    $test->request( GET '/set_views/t/corpus/pretty' );

    # Get another template that is known to exist in the test corpus
    $res = $test->request( GET '/relative.tt' );
    is $res->code, 200, 'got template from other view';
};

done_testing;
