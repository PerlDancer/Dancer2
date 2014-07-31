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
}

my $app    = Dancer2->runner->psgi_app;
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

test_psgi $app, sub {
    my $cb = shift;

    is(
        $cb->( GET '/' )->content,
        $result,
        '[GET /] Correct content with template hooks',
    );
};


{

    package Foo;

    use Dancer2;
    set views => '/this/is/our/path';

    get '/default_views'          => sub { set 'views' };
    get '/set_views_via_settings' => sub { set views => '/other/path' };
    get '/get_views_via_settings' => sub { set 'views' };
}

$app = Dancer2->runner->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    is(
        $cb->( GET '/default_views' )->content,
        '/this/is/our/path',
        '[GET /default_views] Correct content',
    );

    # trigger a test via a route
    $cb->( GET '/set_views_via_settings' );

    is(
        $cb->( GET '/get_views_via_settings' )->content,
        '/other/path',
        '[GET /get_views_via_settings] Correct content',
    );
};

done_testing;
