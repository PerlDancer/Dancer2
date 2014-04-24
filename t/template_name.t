use strict;
use warnings;
use File::Spec;
use File::Basename 'dirname';
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{

    package Foo;

    use Dancer2;

    get '/template_name' => sub {
        return engine('template')->name;
    };
}

my $app = Dancer2->runner->server->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;
    is( $cb->( GET '/template_name' )->content, 'Tiny', 'template name' );
};

done_testing;
