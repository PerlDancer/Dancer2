use strict;
use warnings;
use utf8;

use Encode 'encode_utf8';
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use File::Temp;
use File::Spec;

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
        send_file( $fh, content_type => 'text/plain', charset => 'utf-8' );
    };

    get '/check_content_type' => sub {
        my $temp = File::Temp->new();
        print $temp "hello";
        close $temp;
        send_file($temp->filename, content_type => 'image/png',
                                   system_path  => 1);
    };

    get '/no_streaming' => sub {
        my $file = File::Spec->rel2abs(__FILE__);
        send_file( $file, system_path => 1, streaming => 0 );
    };

    get '/options_streaming' => sub {
        my $file = File::Spec->rel2abs(__FILE__);
        send_file( $file, system_path => 1, streaming => 1 );
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
        is( $r->content_type, 'text/plain', 'expected content_type');
        is( $r->content_type_charset, 'UTF-8', 'expected charset');
        like( $r->content, qr{package StaticContent}, 'filehandle content' );
    };

    subtest "no streaming" => sub {
        my $r = $cb->( GET '/no_streaming' ); 
        is( $r->code, 200, 'send_file set status to 200 (no streaming)');
        like( $r->content, qr{package StaticContent}, 'no streaming - content' );
    };

    subtest "options streaming" => sub {
        my $r = $cb->( GET '/options_streaming' ); 
        is( $r->code, 200, 'send_file set status to 200 (options streaming)');
        like( $r->content, qr{package StaticContent}, 'options streaming - content' );
    };

    subtest 'send_file returns correct content type' => sub {
        my $r = $cb->( GET '/check_content_type' );

        ok($r->is_success, 'send_file returns success');
        is($r->content_type, 'image/png', 'send_file returns correct content_type');
    };
};

done_testing;
