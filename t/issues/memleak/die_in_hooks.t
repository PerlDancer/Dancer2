# reported memory leak without GH issue or RT ticket
use strict;
use warnings;
use Test::More tests => 6;
use Plack::Test;
use Capture::Tiny 'capture_stderr';
use HTTP::Request::Common;

my $called;
{ package Foo::Destroy; sub DESTROY { $called++ } } ## no critic

{
    package App; ## no critic
    use Dancer2;
    my $env_key = 'psgix.ignoreme.refleak';

    hook before => sub {
        request->env->{$env_key} = bless {}, 'Foo::Destroy';
    };

    hook before => sub {
        ::ok( request->env->{$env_key}, 'Object exists' );
        ::isa_ok( request->env->{$env_key}, 'Foo::Destroy', 'It is an object' );

        die "whoops";
    };

    get '/' => sub {'OK'};
}

my $test = Plack::Test->create( App->to_app );
my $res;
my $stderr = capture_stderr { $res = $test->request( GET '/' ) };

ok( ! $res->is_success, 'Request failed' );
is( $res->code, 500, 'Failure status' );
is( $called, 1, 'Memory cleaned' );

# double check stderr
#  '[App:21992] error @2015-03-03 16:39:07> Exception caught in 'core.app.before_request' filter: Hook error: whoops at t/issues/memleak/die_in_hooks.t line 25.
#  at lib/Dancer2/Core/App.pm line 848. in (eval 117) l. 1
#  at ...
# '
like(
    $stderr,
    qr{
        ^
        \[App:\d+\] \s error \s [\@\-\d\s:]+> \s
        \QException caught in 'core.app.before_request' filter:\E \s
        \QHook error: whoops\E \s
        [^\n]+ \n \s*       # everything until newline + newline
        at [^\n]+ \n        # another such line (there could be more)
    }x,
    'Correct error',
);
