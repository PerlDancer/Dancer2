use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw<is_coderef>;
use List::Util qw<all>;

use Dancer2::Core::App;
use Dancer2::Core::Response;
use Dancer2::Core::Request;
use Dancer2::Core::Error;

use JSON::MaybeXS qw/JSON/; # Error serialization

my $env = {
    'psgi.url_scheme' => 'http',
    REQUEST_METHOD    => 'GET',
    SCRIPT_NAME       => '/foo',
    PATH_INFO         => '/bar/baz',
    REQUEST_URI       => '/foo/bar/baz',
    QUERY_STRING      => 'foo=42&bar=12&bar=13&bar=14',
    SERVER_NAME       => 'localhost',
    SERVER_PORT       => 5000,
    SERVER_PROTOCOL   => 'HTTP/1.1',
    REMOTE_ADDR       => '127.0.0.1',
    HTTP_COOKIE =>
      'dancer.session=1234; fbs_102="access_token=xxxxxxxxxx%7Cffffff"',
    HTTP_X_FORWARDED_FOR => '127.0.0.2',
    REMOTE_HOST     => 'localhost',
    HTTP_USER_AGENT => 'Mozilla',
    REMOTE_USER     => 'sukria',
};

my $app     = Dancer2::Core::App->new( name => 'main' );
my $request = $app->build_request($env);

$app->set_request($request);

subtest 'basic defaults of Error object' => sub {
    my $err = Dancer2::Core::Error->new( app => $app );
    is $err->status,  500,                                 'code';
    is $err->title,   'Error 500 - Internal Server Error', 'title';
    is $err->message, '',                               'message';
    like $err->content, qr!http://localhost:5000/foo/css!,
        "error content contains css path relative to uri_base";
};

subtest "send_error in route" => sub {
    {

        package App;
        use Dancer2;

        set serializer => 'JSON';

        get '/error' => sub {
            send_error "This is a custom error message";
            return "send_error returns so this content is not processed";
        };
    }

    my $app = App->to_app;
    ok( is_coderef($app), 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;
        my $r  = $cb->( GET '/error' );

        is( $r->code, 500, 'send_error sets the status to 500' );
        like(
            $r->content,
            qr{This is a custom error message},
            'Error message looks good',
        );

        is(
            $r->content_type,
            'application/json',
            'Response has appropriate content type after serialization',
        );
    };
};

subtest "send_error with custom stuff" => sub {
    {

        package App;
        use Dancer2;

        get '/error/:x' => sub {
            my $x = param('x');
            send_error "Error $x", "5$x";
        };
    }

    my $app = App->to_app;
    ok( is_coderef($app), 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;
        my $r  = $cb->( GET '/error/42' );

        is( $r->code, 542, 'send_error sets the status to 542' );
        like( $r->content, qr{Error 42},  'Error message looks good' );
    };
};

subtest 'Response->error()' => sub {
    my $resp = Dancer2::Core::Response->new;

    isa_ok $resp->error( message => 'oops', status => 418 ),
      'Dancer2::Core::Error';

    is $resp->status    => 418,        'response code is 418';
    like $resp->content => qr/oops/,   'response content overriden by error';
    like $resp->content => qr/teapot/, 'error code title is present';
    ok $resp->is_halted, 'response is halted';
};

subtest 'Throwing an error with a response' => sub {
    my $resp = Dancer2::Core::Response->new;

    my $err = eval { Dancer2::Core::Error->new(
        exception   => 'our exception',
        show_errors => 1
    )->throw($resp) };
      
    isa_ok($err, 'Dancer2::Core::Response', "Error->throw() accepts a response");
};

subtest 'Error with show_errors: 0' => sub {
    my $err = Dancer2::Core::Error->new(
        exception   => 'our exception',
        show_errors => 0
    )->throw;
    unlike $err->content => qr/our exception/;
};

subtest 'Error with show_errors: 1' => sub {
    my $err = Dancer2::Core::Error->new(
        exception   => 'our exception',
        show_errors => 1
    )->throw;
    like $err->content => qr/our exception/;
};

subtest 'App dies with serialized error' => sub {
    {
        package AppDies;
        use Dancer2;
        set serializer => 'JSON';

        get '/die' => sub {
            die "oh no\n"; # I should serialize
        };
    }

    my $app = AppDies->to_app;
    isa_ok( $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;
        my $r  = $cb->( GET '/die' );

        is( $r->code, 500, '/die returns 500' );

        my $out = eval { JSON->new->utf8(0)->decode($r->decoded_content) };
        ok(!$@, 'JSON decoding serializer error produces no errors');
        isa_ok($out, 'HASH', 'Error deserializes to a hash');
        like($out->{exception}, qr/^oh no/, 'Get expected error message');
    };
};

subtest 'Error with exception object' => sub {
    local $@;
    eval { MyTestException->throw('a test exception object') };
    my $err = Dancer2::Core::Error->new(
        exception   => $@,
        show_errors => 1,
    )->throw;

    like $err->content, qr/a test exception object/, 'Error content contains exception message';
};

subtest 'Errors without server tokens' => sub {
    {
        package AppNoServerTokens;
        use Dancer2;
        set serializer => 'JSON';
        set no_server_tokens => 1;

        get '/ohno' => sub {
            die "oh no";
        };
    }

    my $test = Plack::Test->create( AppNoServerTokens->to_app );
    my $r = $test->request( GET '/ohno' );
    is( $r->code, 500, "/ohno returned 500 response");
    is( $r->header('server'), undef, "No server header when no_server_tokens => 1" );
};

subtest 'Errors with show_errors and circular references' => sub {
    {
        package App::ShowErrorsCircRef;
        use Dancer2;
        set show_errors           => 1;
        set something_with_config => {something => config};
        set password              => '===VERY-UNIQUE-STRING===';
        set innocent_thing        => '===VERY-INNOCENT-STRING===';
        set template              => 'simple';

        # Trigger an error that makes Dancer2::Core::Error::_censor enter an
        # infinite loop
        get '/ohno' => sub {
            template q{I don't exist};
        };

    }

    my $test = Plack::Test->create( App::ShowErrorsCircRef->to_app );
    my $r = $test->request( GET '/ohno' );
    is( $r->code, 500, "/ohno returned 500 response");
    like( $r->content, qr{Stack}, 'it includes a stack trace' );

    my @password_values = ($r->content =~ /\bpassword\b(.+)\n/g);
    my $is_password_hidden =
      all { /Hidden \(looks potentially sensitive\)/ } @password_values;

    ok($is_password_hidden, "password was hidden in stacktrace");

    cmp_ok(@password_values, '>', 1,
        'password key appears more than once in the stacktrace');

    unlike($r->content, qr{===VERY-UNIQUE-STRING===},
        'password value does not appear in the stacktrace');

    like($r->content, qr{===VERY-INNOCENT-STRING===},
        'Values for other keys (non-sensitive) appear in the stacktrace');
};

done_testing;


{   # Simple test exception class
    package MyTestException;

    use overload '""' => \&as_str;

    sub new {
        return bless {};
    }

    sub throw {
        my ( $class, $error ) = @_;
        my $self = ref($class) ? $class : $class->new;
        $self->{error} = $error;

        die $self;
    }

    sub as_str { return $_[0]->{error} }
}
