use strict;
use warnings;
use Test::More;
use Plack::Builder;
use Plack::Test;
use HTTP::Request::Common;

{
    package MyTestWiki;
    use Dancer2;
    get '/' => sub { __PACKAGE__ };

    package MyTestForum;
    use Dancer2;
    get '/' => sub { __PACKAGE__ };
}

my $app = builder {
    mount '/wiki'  => MyTestWiki->psgi_app;
    mount '/forum' => MyTestForum->psgi_app;
};

test_psgi $app, sub {
    my $cb = shift;

    is( $cb->( GET '/wiki' )->content, 'MyTestWiki', "Got forum root" );
    is( $cb->( GET '/forum' )->content, 'MyTestForum', "Got wiki root" );
};

done_testing;
