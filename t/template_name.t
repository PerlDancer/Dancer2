use strict;
use warnings;
use File::Spec;
use File::Basename 'dirname';
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw<is_coderef>;

{

    package Foo;

    use Dancer2;

    get '/template_name' => sub {
        return engine('template')->name;
    };
}

my $app = Foo->to_app;
ok( is_coderef($app), 'Got app' );

test_psgi $app, sub {
    my $cb = shift;
    is( $cb->( GET '/template_name' )->content, 'Tiny', 'template name' );
};

done_testing;
