use strict;
use warnings;

use Test::More;

subtest 'halt within routes' => sub {
    {

        package App;
        use Dancer2;

        get '/' => sub { 'hello' };
        get '/halt' => sub {
            header 'X-Foo' => 'foo';
            halt;
        };
        get '/shortcircuit' => sub {
            context->response->content('halted');
            halt;
            redirect '/'; # won't get executed as halt returns immediately.
        };
    }
    use Dancer2::Test apps => ['App'];

    response_status_is  [ GET => '/shortcircuit' ] => 200;
    response_content_is [ GET => '/shortcircuit' ] => "halted";

    my $expected_headers = [
        'X-Foo'        => 'foo',
        'Server'       => "Perl Dancer2 $Dancer2::VERSION",
    ];
    response_headers_include [ GET => '/halt' ] => $expected_headers;

};

subtest 'halt in before halt' => sub {
    {
        package App;
        use Dancer2;

        hook before => sub {
            my $context = shift;
            $context->response->content('I was halted');
            halt if $context->request->dispatch_path eq '/shortcircuit';
        };

    }

    response_status_is  [ GET => '/shortcircuit' ] => 200;
    response_content_is [ GET => '/shortcircuit' ] => "I was halted";

};

done_testing;
