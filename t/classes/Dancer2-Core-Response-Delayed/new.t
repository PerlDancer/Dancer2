use strict;
use warnings;
use Test::More tests => 18;
use Dancer2::Core::Runner;
use Dancer2::Core::Request;
use Dancer2::Core::Response;

use_ok('Dancer2::Core::Response::Delayed');

my $runner = Dancer2::Core::Runner->new;
isa_ok( $runner, 'Dancer2::Core::Runner' );
$Dancer2::runner = $runner;

my $request = Dancer2::Core::Request->new(
    env => { PATH_INFO => '/foo' },
);
isa_ok( $request, 'Dancer2::Core::Request' );

my $response = Dancer2::Core::Response->new();
isa_ok( $response, 'Dancer2::Core::Response' );

my $test    = 0;
my $del_res = Dancer2::Core::Response::Delayed->new(
    request  => $request,
    response => $response,
    cb       => sub {
        ::isa_ok(
            $Dancer2::Core::Route::REQUEST,
            'Dancer2::Core::Request',
        );

        ::isa_ok(
            $Dancer2::Core::Route::RESPONSE,
            'Dancer2::Core::Response',
        );

        ::is(
            $Dancer2::Core::Route::REQUEST->path,
            '/foo',
            'Correct path in the request',
        );

        ::isa_ok(
            $Dancer2::Core::Route::RESPONDER,
            'CODE',
            'Got a responder callback',
        );

        $test++;

        $Dancer2::Core::Route::RESPONDER->('OK');
    },
);

isa_ok( $del_res, 'Dancer2::Core::Response::Delayed' );
can_ok( $del_res, qw<request response cb>          );
can_ok( $del_res, qw<is_halted has_passed to_psgi> );

is( $del_res->is_halted,  0, 'is_halted returns no'  );
is( $del_res->has_passed, 0, 'has_passed returns no' );

my $res_cb = sub { is( $_[0], 'OK', 'Correct response asynchronously' ) };

my $psgi_res = $del_res->to_psgi();
is( $test, 0, 'Callback not run yet' );
$psgi_res->($res_cb);
is( $test, 1, 'Callback run' );

is $del_res->status => 200, "we can access the response header";
isa_ok( $del_res->headers, "HTTP::Headers", "Able to retrieve headers");
