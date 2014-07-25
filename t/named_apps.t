use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;

{

    package Foo;
    use Dancer2;

    hook before => sub { vars->{foo} = 'foo' };

    post '/foo' => sub {
        return vars->{foo} . 'foo' . vars->{baz};
    };
}

{
    package Bar;
    use Dancer2 appname => 'Foo'; # Add routes and hooks to Foo.

    hook before => sub { vars->{baz} = 'baz' };

    post '/bar' => sub {
        return vars->{foo} . 'bar' . vars->{baz};
    }
}

my $app = Dancer2->psgi_app;

test_psgi $app, sub {
    my $cb  = shift;
    for my $path ( qw/foo bar/ ) {
        my $res = $cb->( POST "/$path" );
        is $res->content, "foo${path}baz",
            "Got app content path $path";
    }
};

done_testing;
