use strict;
use warnings;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;
    any [ 'get', 'post' ] => '/test' => sub { request->method };
    any '/all' => sub { request->method };
}

my $test = Plack::Test->create( App->to_app );

subtest 'any with params' => sub {
    my @success = qw<GET POST>;
    my @fails   = qw<PUT DELETE OPTIONS PATCH NONEXIST>;

    foreach my $method (@success) {
        my $req = HTTP::Request->new( $method => '/test' );
        is(
            $test->request($req)->content,
            $method,
            "Method $method works",
        );
    }

    foreach my $method (@fails) {
        my $req = HTTP::Request->new( $method => '/test' );
        ok(
            ! $test->request($req)->is_success,
            "Method $method doesn't exist",
        );
    }
};

subtest 'any without params' => sub {
    foreach my $method ( qw<GET POST PUT DELETE OPTIONS PATCH> ) {
        my $req = HTTP::Request->new( $method => '/all' );
        is(
            $test->request($req)->content,
            $method,
            "Method $method works",
        );
    }
};

