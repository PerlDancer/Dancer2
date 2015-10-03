use Test::More;
use strict;
use warnings;
use Encode;
use utf8;

use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;

    get '/name/:name' => sub {
        "Your name: " . params->{name};
    };

    post '/name' => sub {
        "Your name: " . params->{name};
    };

    get '/unicode' => sub {
        "cyrillic shcha \x{0429}",;
    };

    get '/symbols' => sub {
        '⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙';
    };

    set charset => 'utf-8';
}

my $app = Dancer2->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->( POST "/name", [ name => 'vasya'] );

    is $res->content_type, 'text/html';
    ok $res->content_type_charset
      ;    # we always have charset if the setting is set
    is $res->content, 'Your name: vasya';

    $res = $cb->( GET "/unicode" );

    is $res->content_type,         'text/html';
    is $res->content_type_charset, 'UTF-8';
    is $res->content, Encode::encode( 'utf-8', "cyrillic shcha \x{0429}" );

    $res = $cb->( GET "/symbols" );
    is $res->content_type,         'text/html';
    is $res->content_type_charset, 'UTF-8';
    is $res->content, Encode::encode( 'utf-8', "⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙" );
};

done_testing();
