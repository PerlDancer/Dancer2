use strict;
use warnings;
use File::Spec;
use File::Basename 'dirname';
use Test::More;

eval "use Template;";
if ($@) {
    plan skip_all => 'Template::Toolkit probably missing.';
}

my $views = File::Spec->rel2abs(
    File::Spec->catfile(dirname(__FILE__), 'views'));

{
    package Foo;
    use Dancer 2.0;

    set views    => $views;
    set session  => 'simple';
    set template => "template_toolkit";
    set foo     => "in settings";

    get '/set_vars' => sub {
        session foo => "in session";
    };

    get '/view/:foo' => sub {
        var foo     => "in var";
        template "tokens";
    };
}

use Dancer::Test 'Foo';

my $expected = "perl_version: $]
dancer_version: ${Dancer::VERSION}
settings.foo: in settings
params.foo: 42
session.foo in session
vars.foo: in var";

dancer_response "/set_vars";
response_content_like "/view/42",
  qr{$expected},
  "Response contains all expected tokens";

done_testing;
