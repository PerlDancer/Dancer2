use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;

use Dancer2::Core::App;
use Dancer2::Core::Response;
use Dancer2::Core::Request;
use Dancer2::Core::Error;

use JSON (); # Error serialization
use Capture::Tiny 'capture_stderr';

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
    is( ref $app, 'CODE', 'Got app' );

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
    is( ref $app, 'CODE', 'Got app' );

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

subtest 'Screen out sensitive data' => sub {

    my $settings;
    {
        no warnings 'once';
        $settings = {
          appdir => '/home/dancer2/mywebapp/',
          apphandler => 'PSGI',
          appname => 'mywebapp',
          behind_proxy => 0,
          cardnum => 1234567890123456,
          charset => 'utf-8',
          content_type => 'text/html',
          environment => 'development',
          host => '0.0.0.0',
          layout => 'main',
          log => 'core',
          logger => 'console',
          no_server_tokens => 0,
          pan => 'foobar',
          plugins => {
            Database => {
              charset => 'utf-8',
              connection_check_threshold => 10,
              connections => {
                dancer => {
                  database => 'dancer_study',
                  driver => 'Pg'
                }
              },
              dbi_params => {
                AutoCommit => 1,
                RaiseError => 1,
                pg_enable_utf8 => 1
              },
              handle_class => undef,
              host => 'localhost',
              log_queries => 1,
              on_connect_do => [],
              password => 'my_top_hush_pwrd',
              port => 5432,
              username => 'exotic_tango_dancer'
            }
          },
          port => '3000',
          public_dir => '/home/dancer2/mywebapp/public',
          route_handlers => [
            [
              'AutoPage',
              1
            ]
          ],
          secret => 'Of Their Eyes',
          session => bless( {
            config => {},
            cookie_name => 'dancer.session',
            cookie_path => '/',
            hooks => {
              'engine.session.after_create' => [],
              'engine.session.after_destroy' => [],
              'engine.session.after_flush' => [],
              'engine.session.after_retrieve' => [],
              'engine.session.before_create' => [],
              'engine.session.before_destroy' => [],
              'engine.session.before_flush' => [],
              'engine.session.before_retrieve' => []
            },
            is_http_only => 1,
            is_secure => 0,
            log_cb => sub { "DUMMY" },
            request => bless( {
              _body_params => {
                pass => 'my_top_hush_pwrd',
                path => '/hello',
                user => 'exotic_tango_dancer'
              },
              _chunk_size => 4096,
              _http_body => bless( {
                body => undef,
                buffer => '',
                chunk_buffer => '',
                chunked => '',
                cleanup => 1,
                content_length => '62',
                content_type => 'application/x-www-form-urlencoded',
                length => 62,
                param => {
                  pass => 'my_top_hush_pwrd',
                  path => '/hello',
                  user => 'exotic_tango_dancer'
                },
                param_order => [
                  'user',
                  'pass',
                  'path'
                ],
                part_data => {},
                state => 'done',
                tmpdir => '/tmp',
                upload => {}
              }, 'HTTP::Body::UrlEncoded' ),
              _params => {
                pass => 'my_top_hush_pwrd',
                path => '/hello',
                user => 'exotic_tango_dancer'
              },
              _read_position => 62,
              _route_params => {},
              body => 'user=exotic_tango_dancer&pass=my_top_hush_pwrd&path=%2Fhello',
              cookies => {
                'dancer.session' => bless( {
                  http_only => 0,
                  name => 'dancer.session',
                  path => '/',
                  secure => 0,
                  value => [
                    'V37iHwAAI2gT8ottTrBIEqBdFNXzYndI'
                  ]
                }, 'Dancer2::Core::Cookie' )
              },
              env => {
                CONTENT_LENGTH => '62',
                CONTENT_TYPE => 'application/x-www-form-urlencoded',
                HTTP_ACCEPT => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                HTTP_ACCEPT_ENCODING => 'gzip, deflate',
                HTTP_ACCEPT_LANGUAGE => 'en-US,en;q=0.5',
                HTTP_CONNECTION => 'keep-alive',
                HTTP_COOKIE => 'dancer.session=V37iHwAAI2gT8ottTrBIEqBdFNXzYndI',
                HTTP_DNT => '1',
                HTTP_HOST => 'localhost:5000',
                HTTP_REFERER => 'http://localhost:5000/hello',
                HTTP_USER_AGENT => 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:47.0) Gecko/20100101 Firefox/47.0',
                PATH_INFO => '/login',
                QUERY_STRING => '',
                REMOTE_ADDR => '127.0.0.1',
                REMOTE_PORT => 50315,
                REQUEST_METHOD => 'POST',
                REQUEST_URI => '/login',
                SCRIPT_NAME => '',
                SERVER_NAME => 0,
                SERVER_PORT => 5000,
                SERVER_PROTOCOL => 'HTTP/1.1',
                'plack.request.body' => bless( {
                  pass => 'my_top_hush_pwrd',
                  path => '/hello',
                  user => 'exotic_tango_dancer'
                }, 'Hash::MultiValue' ),
                'plack.request.http.body' => bless( {
                  body => undef,
                  buffer => '',
                  chunk_buffer => '',
                  chunked => '',
                  cleanup => 1,
                  content_length => '62',
                  content_type => 'application/x-www-form-urlencoded',
                  length => 62,
                  param => {
                    pass => 'my_top_hush_pwrd',
                    path => '/hello',
                    user => 'exotic_tango_dancer'
                  },
                  param_order => [
                    'user',
                    'pass',
                    'path'
                  ],
                  part_data => {},
                  state => 'done',
                  tmpdir => '/tmp',
                  upload => {}
                }, 'HTTP::Body::UrlEncoded' ),
                'plack.request.upload' => bless( {}, 'Hash::MultiValue' ),
                'psgi.errors' => *::STDERR,
                #        'psgi.input' => bless( \*{'Stream::Buffered::PerlIO::$io'}, 'FileHandle' ),
                'psgi.input' => '',
                'psgi.multiprocess' => '',
                'psgi.multithread' => '',
                'psgi.nonblocking' => '',
                'psgi.run_once' => '',
                'psgi.streaming' => 1,
                'psgi.url_scheme' => 'http',
                'psgi.version' => [
                  1,
                  1
                ],
                'psgix.harakiri' => 1,
                'psgix.input.buffered' => 1,
                'psgix.io' => bless( \*Symbol::GEN4, 'IO::Socket::INET' )
              },
              headers => bless( {
                accept => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'accept-encoding' => 'gzip, deflate',
                'accept-language' => 'en-US,en;q=0.5',
                connection => 'keep-alive',
                'content-length' => '62',
                'content-type' => 'application/x-www-form-urlencoded',
                cookie => 'dancer.session=V37iHwAAI2gT8ottTrBIEqBdFNXzYndI',
                dnt => '1',
                host => 'localhost:5000',
                referer => 'http://localhost:5000/hello',
                'user-agent' => 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:47.0) Gecko/20100101 Firefox/47.0'
              }, 'HTTP::Headers::Fast' ),
              id => 3,
              is_behind_proxy => '',
              route_parameters => bless( {}, 'Hash::MultiValue' ),
              uploads => {},
              vars => {}
            }, 'Dancer2::Core::Request' ),
            session => bless( {
              data => {},
              id => 'V37iHwAAI2gT8ottTrBIEqBdFNXzYndI',
              is_dirty => 0
            }, 'Dancer2::Core::Session' )
          }, 'Dancer2::Session::Simple' ),
          show_errors => 1,
          startup_info => 1,
          static_handler => 1,
          template => 'simple',
          traces => 0,
          views => '/home/dancer2/mywebapp/views',
          warnings => 1,
        };
    }

    my $censored_count = Dancer2::Core::Error::_censor($settings);
    # In $settings there are 7 instances of 'password' or 'pass' as key in
    # hash or in query string.  There is 1 instance each of 'cardnum', 'pan'
    # or 'secret' as keys.
    is $censored_count, 10, "Got expected censored count";
    my $sensitive = qr/Hidden \(looks potentially sensitive\)/;
    like $settings->{cardnum}, qr/$sensitive/, "'cardnum' hidden";
    like $settings->{pan}, qr/$sensitive/, "'pan' hidden";
    like $settings->{secret}, qr/$sensitive/, "'secret' hidden";
    like $settings->{plugins}{Database}{password}, qr/$sensitive/, "'password' hidden";
    like $settings->{session}{request}{_body_params}{pass}, qr/$sensitive/, "'pass' hidden";
    like $settings->{session}{request}{_http_body}{param}{pass}, qr/$sensitive/, "'pass' hidden";
    like $settings->{session}{request}{_params}{pass}, qr/$sensitive/, "'pass' hidden";
    like $settings->{session}{request}{body}, qr/$sensitive/, "query string with 'pass' hidden";
    like $settings->{session}{request}{env}{'plack.request.body'}{pass}, qr/$sensitive/, "'pass' hidden";
    like $settings->{session}{request}{env}{'plack.request.http.body'}{param}{pass}, qr/$sensitive/, "'pass' hidden";

    my ($arg, $rv, $stderr);
    my $exp_error = qr/_censor given incorrect input/;
    $arg = '';
    $stderr = capture_stderr { $rv = Dancer2::Core::Error::_censor($arg); };
    ok ! defined $rv, "Dancer2::Core::Error::_censor() returned undef due to false argument";
    like $stderr, qr/$exp_error/, "Got expected error message";

    $arg = [];
    $stderr = capture_stderr { $rv = Dancer2::Core::Error::_censor($arg); };
    ok ! defined $rv, "Dancer2::Core::Error::_censor() returned undef due to non-hashref argument";
    like $stderr, qr/$exp_error/, "Got expected error message";

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
