use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

# The hook chain: what runs, in what order, and what happens when a hook dies.
#
# Every app hook is wrapped by App::compile_hooks (Dancer2/Core/App.pm:1313),
# which does three things worth pinning: it skips the hook entirely if the
# response is already halted, it fires core.app.hook_exception when the hook
# dies, and it decides between keeping a response the exception handler set and
# croaking on to the 500 handler.
#
# Traces are collected in package arrays rather than asserted through the
# response body, because several of these cases never reach a route at all and
# the ordering is the thing being tested.
#
# Each of OrderApp/HaltApp/HaltInExceptionApp's PSGI coderef is built exactly
# once, at file scope, simply so every subtest for a given app shares one
# compiled app. Hook compilation is idempotent (see the to_app subtest below),
# so this is no longer load-bearing the way it once was, but there is still
# no reason to rebuild the same app repeatedly.

{
    package OrderApp;
    use Dancer2;
    set logger => 'null';

    our @trace;

    hook on_hook_exception  => sub { push @trace, "hook_exception:$_[2]" };
    hook on_route_exception => sub { push @trace, 'route_exception' };

    hook before => sub {
        push @trace, 'before';
        die "before blew up\n" if request->path =~ /boom/;
    };
    hook after => sub { push @trace, 'after' };

    get '/ok'   => sub { push @trace, 'route';               'OK' };
    get '/boom' => sub { push @trace, 'route-MUST-NOT-RUN';  'NOPE' };
}

{
    package HaltApp;
    use Dancer2;
    set logger => 'null';

    our @trace;

    hook before => sub { push @trace, 'before-1'; halt('HALTED-IN-BEFORE') };
    hook before => sub { push @trace, 'before-2-MUST-NOT-RUN' };
    hook after  => sub { push @trace, 'after-MUST-NOT-RUN' };

    get '/x' => sub { push @trace, 'route-MUST-NOT-RUN'; 'ROUTE' };
}

# A hook_exception handler that sets its own response and halts. The wrapper
# in compile_hooks explicitly supports this (see its comment at
# Dancer2/Core/App.pm:1343-1349): halting in the handler is how it keeps a
# custom response instead of croaking on to the 500 handler.
{
    package HaltInExceptionApp;
    use Dancer2;
    set logger => 'null';

    our @trace;

    hook on_hook_exception => sub {
        my ( $app, $err, $position ) = @_;
        $err =~ s/\n.*//s;
        push @trace, "hook_exception:$position";
        $app->response->status(418);
        $app->response->content('CUSTOM-FROM-HANDLER');
        $app->response->is_halted(1);
    };
    hook on_route_exception => sub { push @trace, 'route_exception' };

    hook before => sub { push @trace, 'before'; die "before blew up\n" };
    hook after  => sub { push @trace, 'after' };

    get '/x' => sub { push @trace, 'route'; 'ROUTE-BODY' };
}

# Built once each - see the note at the top of this file. (RecompiledApp,
# below, deliberately builds its PSGI coderef more than once - that's the
# thing it's testing.)
my $order_test = Plack::Test->create( OrderApp->to_app );
my $halt_test  = Plack::Test->create( HaltApp->to_app );
my $halt_in_exception_test =
    Plack::Test->create( HaltInExceptionApp->to_app );

subtest 'hooks run around the route in order' => sub {
    my $test = $order_test;

    @OrderApp::trace = ();
    my $response = $test->request( GET '/ok' );

    is( $response->code, 200, 'the request succeeds' );
    is( $response->content, 'OK', 'the route produced the body' );
    is_deeply( \@OrderApp::trace, [ 'before', 'route', 'after' ],
        'before, then the route, then after' );
};

subtest 'a dying before hook fires both exception hooks and 500s' => sub {
    my $test = $order_test;

    @OrderApp::trace = ();
    my $response = $test->request( GET '/boom' );

    is( $response->code, 500, 'the request becomes a 500' );

    # Both hooks fire, and hook_exception is told which position died. The
    # route must not run: the before hook refused the request.
    is_deeply(
        \@OrderApp::trace,
        [
            'before',
            'hook_exception:core.app.before_request',
            'route_exception',
        ],
        'hook_exception fires first with the position, then route_exception, and the route never runs',
    );

    like( $response->content, qr/<!DOCTYPE html>/,
        'and an error page is rendered' );
};

subtest 'halt in a before hook stops the whole chain' => sub {
    my $test = $halt_test;

    @HaltApp::trace = ();
    my $response = $test->request( GET '/x' );

    is( $response->code, 200, 'halt keeps the status it was given' );
    is( $response->content, 'HALTED-IN-BEFORE',
        'and the halted body is what is returned' );

    # This is the assertion: exactly one hook ran. A second before hook, the
    # route, and the after hook are all skipped, which is compile_hooks'
    # is_halted check (Dancer2/Core/App.pm:1322-1324) doing its job.
    is_deeply( \@HaltApp::trace, ['before-1'],
        'no later hook and no route runs after halt' );
};

subtest 'a halting hook_exception handler keeps the route refused' => sub {

    # Fixed. The wrapper captures is_halted before deciding whether to
    # call $app->cleanup (Dancer2/Core/App.pm:1335-1342), and now skips
    # cleanup when the response was halted, as well as when this is itself
    # the hook_exception handler. A halt means "this response is final", so
    # the request, response and session the handler set up must survive for
    # dispatch to see - not be cleared out from under it.
    #
    # With cleanup skipped, dispatch's own is_halted check
    # (Dancer2/Core/App.pm:1748, reached via _dispatch_route's check at
    # ~1831) sees the same halted response the handler built, returns it
    # immediately, and neither the route nor the after hook ever run.

    my $test = $halt_in_exception_test;

    @HaltInExceptionApp::trace = ();
    my $response = $test->request( GET '/x' );

    is( $response->code, 418, 'the handler\'s status is what the client gets' );
    is( $response->content, 'CUSTOM-FROM-HANDLER',
        'and the handler\'s body' );

    # The route the before hook refused must never run.
    ok(
        !scalar( grep { $_ eq 'route' } @HaltInExceptionApp::trace ),
        'the route does not run - the before hook\'s refusal holds',
    );

    # The exception handler fires exactly once, for the before hook that
    # really failed. There is no second, spurious failure caused by cleanup
    # destroying state the dispatcher still needed.
    my @exceptions = grep { /^hook_exception:/ } @HaltInExceptionApp::trace;
    is( scalar @exceptions, 1,
        'the exception handler fires exactly once' );
    is( $exceptions[0], 'hook_exception:core.app.before_request',
        'for the before hook that failed' );

    is_deeply(
        \@HaltInExceptionApp::trace,
        [
            'before',
            'hook_exception:core.app.before_request',
        ],
        'the full sequence: before dies, the handler runs, and nothing else',
    );
};

subtest 'to_app compiles the hooks only once, however many times it is called' => sub {

    # Fixed. finish() calls compile_hooks(), which wraps each hook and
    # puts the wrappers back via replace_hook - so a second to_app() would
    # wrap the already-wrapped hooks again, and on the failure path each
    # layer would treat the inner layer's croak as a fresh hook failure and
    # fire core.app.hook_exception itself: a single dying hook reporting N
    # times after N calls to to_app.
    #
    # compile_hooks now records each wrapper it produces in the app's
    # _compiled_hooks registry (Dancer2/Core/App.pm) and passes its own
    # earlier work through untouched, so a hook is wrapped exactly once
    # however many times compile_hooks runs. That restores the single-fire
    # intent the wrapper already states for itself:
    # it carries an explicit guard against firing hook_exception recursively
    # (Dancer2/Core/App.pm:1329-1334), which only ever considered recursion
    # through the handler - it's the second layer of wrapping this closes.
    #
    # Every other app in this file still builds its PSGI coderef once, simply
    # because there's no reason to rebuild it - not because a second call
    # would misbehave, as this subtest demonstrates.

    {
        package RecompiledApp;
        use Dancer2;
        set logger => 'null';

        our @trace;

        hook on_hook_exception  => sub { push @trace, 'hook_exception' };
        hook on_route_exception => sub { push @trace, 'route_exception' };
        hook before => sub { push @trace, 'before'; die "boom\n" };

        get '/x' => sub { 'X' };
    }

    my @counts;
    for my $call ( 1 .. 3 ) {
        my $test = Plack::Test->create( RecompiledApp->to_app );
        @RecompiledApp::trace = ();
        $test->request( GET '/x' );
        push @counts,
            scalar grep { $_ eq 'hook_exception' } @RecompiledApp::trace;
    }

    is( $counts[0], 1,
        'the first to_app reports the failing hook once, correctly' );
    is_deeply( \@counts, [ 1, 1, 1 ],
        'every further to_app still reports the same failure exactly once' );
};

subtest 'a hook registered after the first to_app is still compiled' => sub {

    # The companion to the subtest above, and the reason that fix records
    # individual wrappers rather than setting a single "hooks are compiled"
    # flag on the app. Hooks can arrive after the first compile: finish()
    # adds postponed plugin hooks immediately *after* calling compile_hooks,
    # so a per-app flag would mean a later to_app() left them permanently
    # unwrapped - and an unwrapped hook is not merely unreported, it dies
    # straight out through the dispatcher instead of reaching
    # core.app.hook_exception at all.
    #
    # Asserted through the same observable as the subtest above: a dying
    # hook that reaches the wrapper reports itself exactly once.

    {
        package LateHookApp;
        use Dancer2;
        set logger => 'null';

        our @trace;

        hook on_hook_exception => sub { push @trace, 'hook_exception' };
        get '/x' => sub { 'X' };
    }

    # Compile once with no before hook at all, so the late one below cannot
    # ride in on the first compile.
    LateHookApp->to_app;

    LateHookApp->to_app;    # and again, so the registry has been consulted

    Dancer2->runner->apps->[-1]->add_hook(
        Dancer2::Core::Hook->new(
            name => 'before',
            code => sub { push @LateHookApp::trace, 'late'; die "boom\n" },
        )
    );

    my $test = Plack::Test->create( LateHookApp->to_app );
    @LateHookApp::trace = ();
    $test->request( GET '/x' );

    is( scalar( grep { $_ eq 'late' } @LateHookApp::trace ), 1,
        'the late hook runs' );
    is( scalar( grep { $_ eq 'hook_exception' } @LateHookApp::trace ), 1,
        'and its failure is reported exactly once, so it was wrapped' );
};

done_testing();
