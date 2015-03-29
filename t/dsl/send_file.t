use strict;
use warnings;
use utf8;

use Encode 'encode_utf8';
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use File::Temp;

{
    package StaticContent;

    use Dancer2;
    use Encode 'encode_utf8';

    set views  => 't/corpus/static';
    set public_dir => 't/corpus/static';

    get '/' => sub {
        send_file 'index.html';
    };

    prefix '/some' => sub {
        get '/image' => sub {
            send_file '1x1.png';
            return "send_file returns; this content is ignored";
        };
    };

    get '/stringref' => sub {
        my $string = encode_utf8("This is əɯosəʍɐ an test string");
        send_file( \$string );
    };

    get '/filehandle' => sub {
        open my $fh, "<:raw", __FILE__;
        send_file( $fh, content_type => 'text/plain' );
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
        my $test_string = encode_utf8('áéíóú');
        like(
            $r->content,
            qr{$test_string},
            'Text content contains UTF-8 characters',
        );
    };

    subtest "Binary content" => sub {
        my $r = $cb->( GET '/some/image' );

        is( $r->code, 200, 'send_file sets the status to 200 (binary content)' );
        unlike( $r->content, qr/send_file returns/,
            "send_file returns immediately with content");
        is( $r->header( 'Content-Type' ), 'image/png',
            'correct content_type in response' );
    };

    subtest "string refs" => sub {
        my $r = $cb->( GET '/stringref' );

        is( $r->code, 200, 'send_file set status to 200 (string ref)');
        like( $r->content, qr{test string}, 'stringref content' );
    };

    subtest "filehandles" => sub {
        my $r = $cb->( GET '/filehandle' );

        is( $r->code, 200, 'send_file set status to 200 (filehandle)');
        like( $r->content, qr{package StaticContent}, 'filehandle content' );
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
