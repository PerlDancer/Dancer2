use strict;
use warnings;

use Test::More;
use Test::Fatal qw<exception>;
use Plack::Test;
use HTTP::Request::Common;
use Path::Tiny ();

# Engine hooks - before_template_render and friends - do not belong to the app,
# they belong to an engine the app may not have built yet. App's add_hook
# modifier (Dancer2/Core/App.pm:714-746) handles both cases:
#
#   engine already built -> register straight onto it via hook_candidates
#   engine not yet built -> stash it in postponed_hooks, and
#                           Hookable::_add_postponed_hooks applies it when the
#                           engine is finally constructed
#
# Which branch is taken depends only on whether 'set template => ...' has run
# yet, because that setting's trigger builds the engine immediately. So the two
# apps below differ *only* in the order of two lines, and both must end up with
# a working hook. The postponed branch is the one that silently drops the hook
# if it regresses, and nothing about the app's own behavior would reveal it.

my $VIEWS;
BEGIN {
    $VIEWS = Path::Tiny->tempdir;
    $VIEWS->child('page.tt')->spew_utf8('VIEW[[% marker %]]');
}

# Hook first, engine second: exercises the postponed path.
{
    package PostponedApp;
    use Dancer2;
    set logger => 'null';
    set views  => $VIEWS->stringify;

    our @trace;

    hook before_template_render => sub {
        my $tokens = shift;
        push @trace, 'before_render';
        $tokens->{marker} = 'FROM-POSTPONED-HOOK';
    };
    hook after_template_render => sub { push @trace, 'after_render' };

    # The engine is built here, after both hooks were registered.
    set template => 'template_toolkit';

    get '/page' => sub { template 'page' };
}

# Engine first, hook second: exercises the direct path.
{
    package DirectApp;
    use Dancer2;
    set logger => 'null';
    set views  => $VIEWS->stringify;

    # The engine is built here, before either hook is registered.
    set template => 'template_toolkit';

    our @trace;

    hook before_template_render => sub {
        my $tokens = shift;
        push @trace, 'before_render';
        $tokens->{marker} = 'FROM-DIRECT-HOOK';
    };
    hook after_template_render => sub { push @trace, 'after_render' };

    get '/page' => sub { template 'page' };
}

subtest 'a hook registered before its engine exists still reaches it' => sub {
    my $test = Plack::Test->create( PostponedApp->to_app );

    @PostponedApp::trace = ();
    my $response = $test->request( GET '/page' );

    is( $response->code, 200, 'the page renders' );

    # Both halves matter. The trace proves the hook was called at all; the
    # body proves it was called with the real token hash, early enough for its
    # change to reach the template.
    is_deeply( \@PostponedApp::trace, [ 'before_render', 'after_render' ],
        'both engine hooks ran, in order' );
    is( $response->content, 'VIEW[FROM-POSTPONED-HOOK]',
        'and the token the hook set reached the template' );
};

subtest 'a hook registered after its engine exists also reaches it' => sub {
    my $test = Plack::Test->create( DirectApp->to_app );

    @DirectApp::trace = ();
    my $response = $test->request( GET '/page' );

    is( $response->code, 200, 'the page renders' );
    is_deeply( \@DirectApp::trace, [ 'before_render', 'after_render' ],
        'both engine hooks ran, in order' );
    is( $response->content, 'VIEW[FROM-DIRECT-HOOK]',
        'and the token the hook set reached the template' );
};

# The postponed mechanism is not template-specific. Hookable's
# _add_postponed_hooks works out which engine it is being built for by matching
# the class name against a list of engine types (Dancer2/Core/Role/Hookable.pm:39),
# and every type in that list depends on being named there. A hook for a type
# that falls out of it is dropped in complete silence - no croak, no warning,
# the callback simply never runs. So each type gets its own assertion rather
# than trusting that "engine hooks work" because the template one does.
{
    package AllEnginesApp;
    use Dancer2;
    set logger => 'null';
    set views  => $VIEWS->stringify;

    our @trace;

    # All four registered before any of these engines is built.
    hook 'engine.template.before_render'   => sub { push @trace, 'template' };
    hook 'engine.session.before_flush'     => sub { push @trace, 'session' };
    hook 'engine.serializer.before'        => sub { push @trace, 'serializer' };
    hook 'engine.logger.before'            => sub { push @trace, 'logger' };

    set template   => 'template_toolkit';
    set session    => 'Simple';
    set serializer => 'JSON';

    get '/all' => sub {
        session touched => 1;    # forces a session flush
        info 'a log line';       # forces the logger
        return { rendered => template 'page' };
    };
}

subtest 'postponed hooks reach every kind of engine, not just templates' => sub {
    my $test = Plack::Test->create( AllEnginesApp->to_app );

    @AllEnginesApp::trace = ();
    my $response = $test->request( GET '/all' );

    is( $response->code, 200, 'the request succeeds' );

    my %fired = map { $_ => 1 } @AllEnginesApp::trace;
    ok( $fired{template},   'the template engine got its postponed hook' );
    ok( $fired{session},    'the session engine got its postponed hook' );
    ok( $fired{serializer}, 'the serializer engine got its postponed hook' );
    ok( $fired{logger},     'the logger engine got its postponed hook' );
};

subtest 'an unsupported engine hook name is refused, not ignored' => sub {
    # A typo in an engine hook name must not be silently dropped. It is caught
    # when the engine is built and applies its postponed hooks
    # (Hookable::_add_postponed_hooks), so the failure happens at
    # 'set template' rather than at the hook registration.
    my $err = exception {
        package TypoApp;
        use Dancer2;
        set logger => 'null';
        hook 'engine.template.no_such_hook' => sub { 1 };
        set template => 'template_toolkit';
    };

    ok( defined $err, 'registering an unknown engine hook is fatal' );
    like( $err, qr/does not support the hook/,
        'the message says the hook is not supported' );
    like( $err, qr/no_such_hook/, 'and names the hook that was asked for' );

    # The caller is reported, so a typo in a large app is findable.
    like( $err, qr/TypoApp/, 'and names the package that registered it' );
};

done_testing();
