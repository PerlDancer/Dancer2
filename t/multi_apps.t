use strict;
use warnings;
use Test::More;
use Plack::Builder;
use Plack::Test;
use HTTP::Request::Common;

{
    package MyTestWiki;
    use Dancer2;
    get '/'     => sub { __PACKAGE__ };
    get '/wiki' => sub {'WIKI'};

    package MyTestForum;
    use Dancer2;
    get '/'      => sub { __PACKAGE__ };
    get '/forum' => sub {'FORUM'};
}

{
    my $app = builder {
        mount '/wiki'  => MyTestWiki->to_app;
        mount '/forum' => MyTestForum->to_app;
    };

    isa_ok( $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;

        is( $cb->( GET '/wiki' )->content, 'MyTestWiki', "Got wiki root" );
        is( $cb->( GET '/forum' )->content, 'MyTestForum', "Got forum root" );
    };
}

{
    my $app = Dancer2->psgi_app;
    isa_ok( $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;

        is( $cb->( GET '/wiki' )->content, 'WIKI', 'Got /wiki path' );
        is( $cb->( GET '/forum' )->content, 'FORUM', 'Got /forum path' );
    };
}

done_testing;
