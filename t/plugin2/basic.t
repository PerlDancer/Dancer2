use strict;
use warnings;

use Test::More tests => 6;
use Plack::Test;
use HTTP::Request::Common;

use lib 't/lib';
use poc;

my $test = Plack::Test->create( poc->to_app );

note "poc root"; {
    my $res = $test->request( GET '/' );
    ok $res->is_success;

    my $content = $res->content;
    like $content, qr/added by plugin/;

    like $content, qr/something:1/, 'config parameters are read';

    like $content, qr/Bar loaded/, 'Plugin Bar has been loaded';

    like $content, qr/bazbazbaz/, 'Foo has a copy of Bar';
}

note "poc truncate"; {
    my $res = $test->request( GET '/truncate' );
    like $res->content, qr'helladd';
}

