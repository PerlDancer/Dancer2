use strict;
use warnings;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;

{
    package App::MIME;
    use Dancer2;

    # set some MIME aliases...
    mime->add_type( foo => 'text/foo' );
    mime->add_alias( f => 'foo' );

    # Set default mime type
    set 'default_mime_type' => 'text/bar';

    # test static corpus
    set static_handler => 1;
    set public_dir => 't/corpus/static';

    # added type
    get '/foo' => sub {
        send_file 'empty.foo';
    };

}

my $app = Plack::Test->create( App::MIME->to_app );


subtest 'send_file content type' => sub {
    my $res = $app->request( GET '/foo' );
    ok( $res->is_success, 'Successful request' );
    is( $res->content_type, 'text/foo', '.. and correct mime type');
    
};

# Ref: #1546
subtest 'static handler content type' => sub {
    my $res = $app->request( GET '/empty.foo' );
    ok( $res->is_success, 'Successful request via static handler' );
    is( $res->content_type, 'text/foo', '.. and correct mime type');
};
