use strict;
use warnings;

use Test::More tests => 8;
use Plack::Test;
use HTTP::Request::Common;

use lib 't/lib';
use poc2;

my $test = Plack::Test->create( poc2->to_app );

note "poc2 root"; {
    my $res = $test->request( GET '/' );
    ok $res->is_success;

    my $content = $res->content;
    like $content, qr/please/;
    like $content, qr/8-D/;
}

note "pos2 goodbye"; {
    my $res = $test->request( GET '/goodbye' );
    ok $res->is_success;

    my $content = $res->content;
    like $content, qr/farewell/;
    like $content, qr/please/;
}

note "pos2 hooked"; {
    my $res = $test->request( GET '/sudo' );
    ok ! $res->is_success;

    my $content = $res->content;
    like $content, qr/Not in sudoers file/;
}
