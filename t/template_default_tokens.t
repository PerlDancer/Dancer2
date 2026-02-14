use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw<is_coderef>;
use Path::Tiny qw< path >;

eval { require Template; Template->import(); 1 }
  or plan skip_all => 'Template::Toolkit probably missing.';

my $views = path( __FILE__ )->parent->child('views')->absolute->stringify;

{

    package Foo;

    use Dancer2;
    set session => 'Simple';

    set views    => $views;
    set template => "template_toolkit";
    set foo      => "in settings";

    get '/view/:foo' => sub {
        var     foo => "in var";
        session foo => "in session";
        template "tokens";
    };
}

my $version = Dancer2->VERSION;
my $expected = "perl_version: $^V
dancer_version: ${version}
settings.foo: in settings
params.foo: 42
session.foo in session
vars.foo: in var";

my $app = Foo->to_app;
ok( is_coderef($app), 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    like(
        $cb->( GET '/view/42' )->content,
        qr{$expected},
        'Response contains all expected tokens',
    );
};

done_testing;
