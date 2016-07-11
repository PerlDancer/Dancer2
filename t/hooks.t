use strict;
use warnings;
use Test::More;
use File::Spec;
use Plack::Test;
use HTTP::Request::Common;
use Capture::Tiny 0.12 'capture_stderr';
use JSON::MaybeXS;

eval { require Template; 1; }
    or plan skip_all => 'Template::Toolkit not present';

my $tests_flags = {};

{
    package App::WithSerializer;
    use Dancer2;
    set serializer => 'JSON';

    my @hooks = qw(
        before_request
        after_request

        before_serializer
        after_serializer
    );

    for my $hook (@hooks) {
        hook $hook => sub {
            $tests_flags->{$hook} ||= 0;
            $tests_flags->{$hook}++;
        };
    }

    get '/' => sub { +{ "ok" => 1 } };

    hook 'before_serializer' => sub {
        my ($data) = @_;  # don't shift, want to alias..
        if ( ref $data eq 'ARRAY' ) {
            push( @{$data}, ( added_in_hook => 1 ) );
        } elsif ( ref $data eq 'HASH' ) {
            $data->{'added_in_hook'} = 1;
        } else {
            $_[0] = +{ 'added_in_hook' => 1 };
        }
    };

    get '/forward' => sub { Test::More::note 'About to forward!'; forward '/' };

    get '/redirect' => sub { redirect '/' };

    get '/json' => sub { +[ foo => 42 ] };

    get '/nothing' => sub { return };
}

{
    package App::WithFile;
    use Dancer2;
    my @hooks = qw<
        before_file_render
        after_file_render
    >;

    for my $hook (@hooks) {
        hook $hook => sub {
            $tests_flags->{$hook} ||= 0;
            $tests_flags->{$hook}++;
        };
    }

    get '/send_file' => sub {
        send_file( File::Spec->rel2abs(__FILE__), system_path => 1 );
    };
}

{
    package App::WithTemplate;
    use Dancer2;
    set template => 'tiny';

    my @hooks = qw(
        before_template_render
        after_template_render
    );

    for my $hook (@hooks) {
        hook $hook => sub {
            $tests_flags->{$hook} ||= 0;
            $tests_flags->{$hook}++;
        };
    }

    get '/template' => sub {
        template \"PLOP";
    };
}

{
    package App::WithIntercept;
    use Dancer2;

    get '/intercepted' => sub {'not intercepted'};

    hook before => sub {
        response->content('halted by before');
        halt;
    };
}

{
    package App::WithError;
    use Dancer2;

    my @hooks = qw(
        on_route_exception
    );

    for my $hook (@hooks) {
        hook $hook => sub {
            $tests_flags->{$hook} ||= 0;
            $tests_flags->{$hook}++;
        };
    }

    get '/route_exception' => sub {die 'this is a route exception'};

    hook after => sub {
        # GH#540 - ensure setting default scalar does not
        # interfere with hook execution (aliasing)
        $_ = 42;
    };

    hook on_route_exception => sub {
        my ($app, $error) = @_;
        ::is ref($app), 'Dancer2::Core::App';
        ::like $error, qr/this is a route exception/;
    };

    hook init_error => sub {
        my ($error) = @_;
        ::is ref($error), 'Dancer2::Core::Error';
    };

    hook before_error => sub {
        my ($error) = @_;
        ::is ref($error), 'Dancer2::Core::Error';
    };

    hook after_error => sub {
        my ($response) = @_;
        ::is ref($response), 'Dancer2::Core::Response';
        ::ok !$response->is_halted;
        ::like $response->content, qr/Internal Server Error/;
    };
}

subtest 'Request hooks' => sub {
    my $test = Plack::Test->create( App::WithSerializer->to_app );
    $test->request( GET '/' );

    is( $tests_flags->{before_request},     1,     "before_request was called" );
    is( $tests_flags->{after_request},      1,     "after_request was called" );
    is( $tests_flags->{before_serializer},  1, "before_serializer was called" );
    is( $tests_flags->{after_serializer},   1, "after_serializer was called" );
    is( $tests_flags->{before_file_render}, undef, "before_file_render undef" );

    note 'after hook called once per request';
    # Get current value of the 'after_request' tests flag.
    my $current = $tests_flags->{after_request};

    $test->request( GET '/redirect' );
    is(
        $tests_flags->{after_request},
        ++$current,
        "after_request called after redirect",
    );

    note 'Serializer hooks';

    $test->request( GET '/forward' );
    is(
        $tests_flags->{after_request},
        ++$current,
        "after_request called only once after forward",
    );

    my $res = $test->request( GET '/json' );
    is( $res->content, '["foo",42,"added_in_hook",1]', 'Response serialized' );
    is( $tests_flags->{before_serializer}, 4, 'before_serializer was called' );
    is( $tests_flags->{after_serializer},  4, 'after_serializer was called' );
    is( $tests_flags->{before_file_render}, undef, "before_file_render undef" );

    $res = $test->request( GET '/nothing' );
    is( $res->content, '{"added_in_hook":1}', 'Before hook modified content' );
    is( $tests_flags->{before_serializer}, 5, 'before_serializer was called with no content' );
    is( $tests_flags->{after_serializer},  5, 'after_serializer was called after content changes in hook' );
};

subtest 'file render hooks' => sub {
    my $test = Plack::Test->create( App::WithFile->to_app );
    $test->request( GET '/send_file' );
    is( $tests_flags->{before_file_render}, 1, "before_file_render was called" );
    is( $tests_flags->{after_file_render},  1, "after_file_render was called" );
};

subtest 'template render hook' => sub {
    my $test = Plack::Test->create( App::WithTemplate->to_app );

    $test->request( GET '/template' );
    is(
        $tests_flags->{before_template_render},
        1,
        "before_template_render was called",
    );

    is(
        $tests_flags->{after_template_render},
        1,
        "after_template_render was called",
    );
};

subtest 'before can halt' => sub {
    my $test = Plack::Test->create( App::WithIntercept->to_app );
    my $resp = $test->request( GET '/intercepted' );
    is( $resp->content, 'halted by before' );
};

subtest 'route_exception' => sub {
    my $test = Plack::Test->create( App::WithError->to_app );
    capture_stderr { $test->request( GET '/route_exception' ) };
};

done_testing;
