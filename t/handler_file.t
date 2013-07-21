use strict;
use warnings;

use Test::More;

{

    package StaticContent;

    use Dancer2;

    engine('template')->views('t/corpus/static');
    $ENV{DANCER_PUBLIC} = 't/corpus/static';

    get '/' => sub {
        send_file 'index.html';
    };

    get '/image' => sub {
        send_file '1x1.png';
    };
}

use Dancer2::Test apps => ['StaticContent'];

subtest "Text content" => sub {
    my $r = dancer_response GET => '/';

    is $r->status, 200, 'send_file sets the status to 200';
    my $charset = $r->headers->content_type_charset;
    is $charset, 'UTF-8', "Text content type has UTF-8 charset";
    like $r->content, qr{áéíóú}, "Text content contains UTF-8 characters";
};

subtest "Binary content" => sub {
    my $r = dancer_response GET => "/image";

    is $r->status, 200, 'send_file sets the status to 200';
};

done_testing;
