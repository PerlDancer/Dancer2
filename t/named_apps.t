use strict;
use warnings;
use File::Spec;
use File::Basename 'dirname';
use Test::More;

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

use Dancer2::Test apps => ['Foo'];

for my $path ( qw/foo bar/ ) {
    my $response = dancer_response(POST => "/$path" );
    is $response->content, "foo${path}baz";
}

done_testing;
