use strict;
use warnings;
use Test::More;
use Dancer::Core::Hook;

use File::Spec;
use File::Basename 'dirname';

eval "use Template;";
if ($@) {
    plan skip_all => 'Template::Toolkit probably missing.';
}

use_ok('Dancer::Template::TemplateToolkit');

my $views = File::Spec->rel2abs(
    File::Spec->catfile(dirname(__FILE__), 'views'));

my $tt = Dancer::Template::TemplateToolkit->new(
    views => $views,
    layout => 'main.tt',
);

isa_ok $tt, 'Dancer::Template::TemplateToolkit';
ok $tt->does('Dancer::Core::Role::Template');

$tt->add_hook(Dancer::Core::Hook->new(
    name => 'engine.template.before_render',
    code => sub {
        my $tokens = shift;
        $tokens->{before_template_render} = 1;
    },
));

$tt->add_hook(Dancer::Core::Hook->new(
    name => 'engine.template.before_layout_render',
    code => sub {
        my $tokens = shift;
        my $content = shift;

        $tokens->{before_layout_render} = 1;
        $$content .= "\ncontent added in before_layout_render";
    },
));

$tt->add_hook(Dancer::Core::Hook->new(
    name => 'engine.template.after_layout_render',
    code => sub {
        my $content = shift;
        $$content .= "\ncontent added in after_layout_render";
    },
));

$tt->add_hook(Dancer::Core::Hook->new(
    name => 'engine.template.after_render',
    code => sub {
        my $content = shift;
        $$content .= 'content added in after_template_render';
    },
));

my $result = $tt->process('index.tt', { var => 42 });
is $result, 'layout top
var = 42
before_layout_render = 1
---
[index]
var = 42

before_layout_render =
before_template_render = 1
content added in after_template_render
content added in before_layout_render
---
layout bottom

content added in after_layout_render';

done_testing;
