use strict;
use warnings;
use Test::Fatal;
use Test::More;

BEGIN {

    # Freeze time at Tue, 15-Jun-2010 00:00:00 GMT
    *CORE::GLOBAL::time = sub { return 1276560000 }
}

use Dancer2::Core::Cookie;
use Dancer2::Core::Request;

diag "If you want extra speed, install HTTP::XSCookies"
  if !Dancer2::Core::Cookie::_USE_XS;

sub run_test {

    note "Constructor";

    my $cookie = Dancer2::Core::Cookie->new( name => "foo" );

    isa_ok $cookie => 'Dancer2::Core::Cookie';
    can_ok $cookie => 'to_header';


    note "Setting values";

    is $cookie->value("foo") => "foo";
    is $cookie->value        => "foo";

    is $cookie . "bar", "foobar", "Stringifies to desired value";

    ok $cookie->value( [qw(a b c)] );
    is $cookie->value => 'a';
    is_deeply [ $cookie->value ] => [qw(a b c)];

    ok $cookie->value( { x => 1, y => 2 } );
    like $cookie->value => qr/^[xy]$/;    # hashes doesn't store order...
    is_deeply [ sort $cookie->value ] => [ sort ( 1, 2, 'x', 'y' ) ];


    note "accessors and defaults";

    is $cookie->name        => 'foo';
    is $cookie->name("bar") => "bar";
    is $cookie->name        => 'bar';

    ok !$cookie->domain;
    is $cookie->domain("dancer.org") => "dancer.org";
    is $cookie->domain               => "dancer.org";
    is $cookie->domain("")           => "";
    ok !$cookie->domain;

    is $cookie->path => '/', "by default, path is /";
    ok $cookie->has_path, "has_path";
    is $cookie->path("/foo") => "/foo";
    ok $cookie->has_path, "has_path";
    is $cookie->path => "/foo";

    ok !$cookie->secure;
    is $cookie->secure(1) => 1;
    is $cookie->secure    => 1;
    is $cookie->secure(0) => 0;
    ok !$cookie->secure;

    ok !$cookie->http_only;
    is $cookie->http_only(1) => 1;
    is $cookie->http_only    => 1;
    is $cookie->http_only(0) => 0;
    ok !$cookie->http_only;

    like exception { $cookie->same_site('foo') },
        qr/foo is not any of the possible values: Strict, Lax!/;

    note "expiration strings";

    my $min  = 60;
    my $hour = 60 * $min;
    my $day  = 24 * $hour;
    my $week = 7 * $day;
    my $mon  = 30 * $day;
    my $year = 365 * $day;

    ok !$cookie->expires;
    my %times = (
        "+2"                                   => "Tue, 15-Jun-2010 00:00:02 GMT",
        "+2h"                                  => "Tue, 15-Jun-2010 02:00:00 GMT",
        "-2h"                                  => "Mon, 14-Jun-2010 22:00:00 GMT",
        "1 hour"                               => "Tue, 15-Jun-2010 01:00:00 GMT",
        "3 weeks 4 days 2 hours 99 min 0 secs" => "Sat, 10-Jul-2010 03:39:00 GMT",
        "2 months"                             => "Sat, 14-Aug-2010 00:00:00 GMT",
        "12 years"                             => "Sun, 12-Jun-2022 00:00:00 GMT",

        1288817656 => "Wed, 03-Nov-2010 20:54:16 GMT",
        1288731256 => "Tue, 02-Nov-2010 20:54:16 GMT",
        1288644856 => "Mon, 01-Nov-2010 20:54:16 GMT",
        1288558456 => "Sun, 31-Oct-2010 20:54:16 GMT",
        1288472056 => "Sat, 30-Oct-2010 20:54:16 GMT",
        1288385656 => "Fri, 29-Oct-2010 20:54:16 GMT",
        1288299256 => "Thu, 28-Oct-2010 20:54:16 GMT",
        1288212856 => "Wed, 27-Oct-2010 20:54:16 GMT",

        # Anything not understood is passed through
        "basset hounds got long ears" => "basset hounds got long ears",
        "+2 something"                => "+2 something",
    );

    for my $exp ( keys %times ) {
        my $want = $times{$exp};

        $cookie->expires($exp);
        is $cookie->expires => $want;
    }


    note "to header";

    my @cake = (
        {   cookie => {
                name    => 'bar',
                value   => 'foo',
                expires => '+2h',
                secure  => 1
            },
            expected =>
            sprintf( "bar=foo; Expires=%s; Path=/; Secure", $times{'+2h'} ),
        },
        {   cookie => {
                name      => 'bar',
                value     => 'foo',
                domain    => 'dancer.org',
                path      => '/dance',
                http_only => 1
            },
            expected => "bar=foo; Domain=dancer.org; HttpOnly; Path=/dance",
        },
        {   cookie => {
                name  => 'bar',
                value => 'foo',
            },
            expected => "bar=foo; Path=/",
        },
        {   cookie => {
                name      => 'same-site',
                value     => 'strict',
                same_site => 'Strict',
            },
            expected => 'same-site=strict; Path=/; SameSite=Strict',
        },
        {   cookie => {
                name      => 'same-site',
                value     => 'lax',
                same_site => 'Lax',
            },
            expected => 'same-site=lax; Path=/; SameSite=Lax',
        },
    );

    for my $cook (@cake) {
        my $c = Dancer2::Core::Cookie->new(%{$cook->{cookie}});
        # name=value; sorted fields
        my @a = split /; /, $c->to_header;
        is join("; ", shift @a, sort @a), $cook->{expected};
    }

    note 'multi-value';

    my $c = Dancer2::Core::Cookie->new( name => 'foo', value => [qw/bar baz/] );

    is $c->to_header, 'foo=bar&baz; Path=/';

    my $r = Dancer2::Core::Request->new( env => { HTTP_COOKIE => 'foo=bar&baz' } );

    is_deeply [ $r->cookies->{foo}->value ], [qw/bar baz/];
}

note "Run test with XS_HTTP_COOKIES" if Dancer2::Core::Cookie::_USE_XS;
run_test();
if ( Dancer2::Core::Cookie::_USE_XS ) {
    note "Run test without XS_HTTP_COOKIES";
    no warnings 'redefine';
    *Dancer2::Core::Cookie::to_header = \&Dancer2::Core::Cookie::pp_to_header;
    run_test();
}

done_testing;
