use strict;
use warnings;

use Test::More;
use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;
use HTTP::Request;

# Each concern gets its own Dancer2 application, because routes are registered
# per package and mixing them would make the match order hard to follow.
# 'logger => null' keeps the suite quiet; these tests assert on responses, not
# on log output.

{
    package FlowPass;
    use Dancer2;
    set logger => 'null';

    our @trace;

    # Matches first, hands off to the next route via pass().
    get '/x/*' => sub {
        push @trace, 'splat=[' . join( ',', splat() ) . ']';
        response->content('CONTENT-FROM-FIRST-ROUTE');
        pass;
    };

    # Deliberately has no wildcard of its own, so anything splat-shaped it
    # sees must have leaked from the route above.
    get '/x/one' => sub {
        push @trace, 'param_keys=[' . join( ',', sort keys %{ params() } ) . ']';
        push @trace, 'content=[' . ( response->content // 'undef' ) . ']';
        return 'SECOND';
    };
}

{
    package FlowHalt;
    use Dancer2;
    set logger => 'null';

    our @trace;

    hook after => sub { push @trace, 'after-hook' };

    get '/halt' => sub {
        halt('HALTED-BODY');
        push @trace, 'code-after-halt';
        return 'NOT-THIS';
    };

    get '/normal' => sub { 'NORMAL' };
}

{
    package FlowForward;
    use Dancer2;
    set logger => 'null';

    post '/plain'         => sub { forward '/dst' };
    post '/with-params'   => sub { forward '/dst', { added => 'yes' } };
    post '/as-get'        => sub { forward '/dst', { added => 'yes' }, { method => 'GET' } };

    # The body is reported through both accessors on purpose. They are carried
    # across a forward by two different lines of the request-cloning code, so
    # checking only one of them leaves the other free to regress unnoticed.
    sub _report {
        my $method = shift;
        join ' ', $method,
            'name='     . ( body_parameters->get('name') // 'undef' ),
            'bodyname=' . ( params('body')->{name}       // 'undef' ),
            'added='    . ( params->{added}              // 'undef' );
    }

    post '/dst' => sub { _report('POST') };
    get  '/dst' => sub { _report('GET') };
}

{
    package FlowRedirect;
    use Dancer2;
    set logger  => 'null';
    set session => 'Simple';

    get '/go'      => sub { redirect '/target' };
    get '/go-abs'  => sub { redirect 'http://elsewhere.example/x' };
    get '/go-301'  => sub { redirect '/target', 301 };
    get '/target'  => sub { 'TARGET' };

    get '/set-then-forward' => sub { session foo => 'bar'; forward '/read' };
    get '/read'             => sub { 'foo=' . ( session('foo') // 'undef' ) };
}

subtest 'pass hands off without leaking state into the next route' => sub {
    my $test = Plack::Test->create( FlowPass->to_app );

    @FlowPass::trace = ();
    my $res = $test->request( GET '/x/one' );

    is( $res->code, 200, 'the second route produced the response' );
    is( $res->content, 'SECOND', 'the body comes from the second route' );

    is( $FlowPass::trace[0], 'splat=[one]',
        'the first route did capture a splat before passing' );

    # These two are the point of the subtest: whatever the first route left
    # behind must not be visible to the second.
    is( $FlowPass::trace[1], 'param_keys=[]',
        'the first route\'s splat parameter does not leak into the second' );
    is( $FlowPass::trace[2], 'content=[undef]',
        'the first route\'s content does not leak into the second' );
};

subtest 'halt stops the route and skips after hooks' => sub {
    my $test = Plack::Test->create( FlowHalt->to_app );

    @FlowHalt::trace = ();
    my $normal = $test->request( GET '/normal' );
    is( $normal->content, 'NORMAL', 'the ordinary route responds normally' );
    is_deeply( \@FlowHalt::trace, ['after-hook'],
        'the after hook does run on an ordinary request' );

    @FlowHalt::trace = ();
    my $halted = $test->request( GET '/halt' );
    is( $halted->code, 200, 'halt keeps the status it was given' );
    is( $halted->content, 'HALTED-BODY', 'the halted body is what is returned' );

    # The comparison against the ordinary request above is what makes this
    # meaningful: the hook demonstrably fires, and demonstrably does not here.
    is_deeply( \@FlowHalt::trace, [],
        'neither the rest of the route nor the after hook runs after halt' );
};

subtest 'forward re-dispatches while preserving the request' => sub {
    my $test = Plack::Test->create( FlowForward->to_app );

    is(
        $test->request( POST '/plain', [ name => 'ovid' ] )->content,
        'POST name=ovid bodyname=ovid added=undef',
        'the body survives the forward through both accessors, method unchanged',
    );

    is(
        $test->request( POST '/with-params', [ name => 'ovid' ] )->content,
        'POST name=ovid bodyname=ovid added=yes',
        'parameters added at forward time are visible to the target',
    );

    is(
        $test->request( POST '/as-get', [ name => 'ovid' ] )->content,
        'GET name=ovid bodyname=ovid added=yes',
        'method => GET reaches the GET route, still carrying the body',
    );
};

subtest 'a session created before a forward is visible after it' => sub {
    my $test = Plack::Test->create( FlowRedirect->to_app );

    is( $test->request( GET '/set-then-forward' )->content, 'foo=bar',
        'the forwarded-to route sees the session set before the forward' );
};

subtest 'redirect sets Location and honours the mount path' => sub {
    my $app  = FlowRedirect->to_app;
    my $test = Plack::Test->create($app);

    my $res = $test->request( GET '/go' );
    is( $res->code, 302, 'a redirect defaults to 302' );
    is( $res->header('Location'), '/target', 'the destination is set verbatim at the root' );

    is( $test->request( GET '/go-301' )->code, 301,
        'an explicit status is used instead of the default' );

    is(
        $test->request( GET '/go-abs' )->header('Location'),
        'http://elsewhere.example/x',
        'an absolute URL is left alone',
    );

    # The same application, mounted somewhere other than '/'. This is the
    # assertion that fails if the mount path stops being prepended.
    my $mounted = Plack::Test->create( builder { mount '/sub' => $app; } );
    is(
        $mounted->request( GET 'http://localhost/sub/go' )->header('Location'),
        '/sub/target',
        'a root-relative redirect is rewritten to include the mount path',
    );
};

subtest 'an unsupported HTTP method is refused with 405' => sub {
    my $test = Plack::Test->create( FlowForward->to_app );

    my $res = $test->request( HTTP::Request->new( 'FROB', '/dst' ) );
    is( $res->code, 405, 'an unknown verb is rejected' );
    like( $res->content, qr/Method Not Allowed/, 'the body says why' );
    like( $res->content, qr/FROB/, 'the body names the offending method' );

    is( $test->request( GET '/dst' )->code, 200,
        'a supported verb on the same path still works' );
};

done_testing();
