use strict;
use warnings;
use Test::More;

# Dancer2 2.1.0 regression: the `path` (and `dirname`) DSL keywords silently
# drop their first argument when called with 2+ path segments.
#
# Root cause (Dancer2::Core::DSL, 2.1.0):
#   sub _path_obj { shift and Path::Tiny::path(@_) }
#   sub path      { shift and _path_obj(@_)->stringify }
#
# path() already shifts off its DSL invocant before calling _path_obj(@_).
# _path_obj then shifts *again*, as if it too were called as a method, but
# it's a plain function call -- so it eats the first real path segment
# instead of an invocant. dirname() shares the same broken helper.
#
# Documented behavior (Dancer2::Manual::Keywords, "path"): "Concatenates
# multiple paths together" -- i.e. path('t','views') should be 't/views'.
# Confirmed correct under Dancer2 2.0.1; broken under 2.1.0.

package TestApp;
use Dancer2;
package main;

my $dsl = TestApp->dsl;

is( $dsl->path('t', 'views'), 't/views',
    'path() with 2 segments keeps all segments (documented: concatenates)' );

is( $dsl->path('a', 'b', 'c'), 'a/b/c',
    'path() with 3 segments keeps all segments' );

# Single-argument calls are even worse: _path_obj's spurious shift eats the
# only argument, leaving Path::Tiny::path() with zero args, which dies
# outright instead of returning a wrong-but-harmless string.
my $single_arg_result = eval { $dsl->dirname('t/views/x.tt') };
my $single_arg_error  = $@;
ok( defined $single_arg_result && !$single_arg_error,
    'dirname() with a single argument does not crash' )
    or diag("dirname('t/views/x.tt') died: $single_arg_error");

is( $single_arg_result, 't/views',
    'dirname() of a single-argument path is correct' ) if defined $single_arg_result;

# Knock-on effect: this is exactly how Dancer2::Plugin::FlashNote's test
# suite sets its views directory (t/01-default.t):
#   setting views => path( 't', 'views' );
# Under the bug, `views` silently becomes just 'views' (the 't' is lost),
# so every template lookup 404s and every route handler that renders a
# template returns a 500 -- which is what caused ~114/160 FlashNote
# subtests to fail under 2.1.0 while the plugin's own code never changed.

done_testing();
