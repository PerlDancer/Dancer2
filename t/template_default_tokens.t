use strict;
use warnings;
use File::Spec;
use File::Basename 'dirname';
use Test::More;

eval { require Template; Template->import(); 1 }
  or plan skip_all => 'Template::Toolkit probably missing.';

my $views =
  File::Spec->rel2abs( File::Spec->catfile( dirname(__FILE__), 'views' ) );

{

    package Foo;

    use Dancer2;
    set session => 'Simple';

    set views    => $views;
    set template => "template_toolkit";
    set foo      => "in settings";

    get '/view/:foo' => sub {
        var foo     => "in var";
        session foo => "in session";
        template "tokens";
    };
}

use Dancer2::Test apps => ['Foo'];

my $expected = "perl_version: $]
dancer_version: ${Dancer2::VERSION}
settings.foo: in settings
params.foo: 42
session.foo in session
vars.foo: in var";

response_content_like "/view/42",
  qr{$expected},
  "Response contains all expected tokens";

done_testing;
