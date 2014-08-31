use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use File::Temp;

{
    package StaticContent;

    use Dancer2;

    set views  => 't/corpus/static';
    set public => 't/corpus/static';

    get '/' => sub {
        send_file 'index.html';
    };

    prefix '/some' => sub {
        get '/image' => sub {
            send_file '1x1.png';
            return "send_file returns; this content is ignored";
        };
    };

    get '/check_content_type' => sub {
        my $temp = File::Temp->new();
        print $temp "hello";
        close $temp;
        send_file($temp->filename, content_type => 'image/png',
                                   system_path  => 1);
    };
}

my $app = StaticContent->to_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    subtest "Text content" => sub {
        my $r = $cb->( GET '/' );

        is( $r->code, 200, 'send_file sets the status to 200' );

        my $charset = $r->headers->content_type_charset;
        is( $charset, 'UTF-8', 'Text content type has UTF-8 charset' );
        like(
            $r->content,
            qr{áéíóú},
            'Text content contains UTF-8 characters',
        );
    };

    subtest "Binary content" => sub {
        my $r = $cb->( GET '/some/image' );

        is( $r->code, 200, 'send_file sets the status to 200' );
        unlike( $r->content, qr/send_file returns/,
            "send_file returns immediately with content");
        is( $r->header( 'Content-Type' ), 'image/png',
            'correct content_type in response' );
    };
};

test_psgi $app, sub {
    my $cb = shift;

    subtest 'send_file returns correct content type' => sub {
        my $r = $cb->( GET '/check_content_type' );

        ok($r->is_success, 'send_file returns success');
        is($r->content_type, 'image/png', 'send_file returns correct content_type');
    };
};

done_testing;
