use Test::More;
use strict;
use warnings;
use Encode;
use utf8;

use Plack::Test;
use HTTP::Request;

{
    package App;
    use Dancer2;
    set charset => 'utf-8';

    any '/foo' => sub {
        header "Allow" => "HEAD,GET,PUT,POST,DELETE,OPTIONS,PATCH";
        "foo";
    };
}

my $app = Dancer2->runner->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub{
    my $cb = shift;

    # Ensure the standalone standaloneerver responds to all the
    # HTTP methods the DSL supports
    for my $method ( qw/HEAD GET PUT POST DELETE OPTIONS PATCH/ ) {
        my $req = HTTP::Request->new($method => "/foo");
        my $res = $cb->($req);

        is $res->content, "foo" if $method ne 'HEAD';
        is $res->content, ""    if $method eq 'HEAD';

        ok( $res->is_success, "$method return a 200 response");
    }
};

done_testing();
