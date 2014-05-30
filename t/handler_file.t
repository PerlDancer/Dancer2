use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{
    package StaticContent;

    use Dancer2;

    engine('template')->views('t/corpus/static');
    $ENV{DANCER_PUBLIC} = 't/corpus/static';

    get '/' => sub {
        send_file 'index.html';
    };

    prefix '/some' => sub {
        get '/image' => sub {
            send_file '1x1.png';
            return "send_file returns; this content is ignored";
        };
    };
}

my $app = Dancer2->runner->psgi_app;
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
        unlike( $r->content, qr/send_file returns/, "send_file returns immediately with content");
    };
};

done_testing;
