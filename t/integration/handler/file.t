use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request;
use HTTP::Request::Common;
use Path::Tiny ();

# Dancer2 serves files from disk by three different code paths, and they do
# not agree with each other. This file pins all three:
#
#   1. send_file            - Dancer2::Core::App::send_file, called from a route.
#   2. the static handler   - on by default; Plack::App::File wrapped in
#                             Plack::Middleware::Conditional by App::to_app,
#                             so it runs *before* the application.
#   3. Dancer2::Handler::File - off by default; a real route (/**) registered
#                             into the application when config asks for it.
#
# Where they disagree, the disagreement is asserted rather than smoothed over.
# One of those disagreements was a security hole - Dancer2::Handler::File
# serving files outside public_dir - and is pinned by the ../ subtests below.

# --- fixture tree ---------------------------------------------------------
#
# Built in a BEGIN block: the third application needs a config.yml on disk
# before its own 'use Dancer2' runs, because route_handlers is read once when
# the application object is constructed at import time. A later 'set' is too
# late, which is why this is a config file and not a setting.
#
#   $ROOT/secret.txt          <- outside the public directory, must stay unreachable
#   $ROOT/public/hello.txt
#   $ROOT/public/locked.txt   <- mode 0000
#   $ROOT/public/shadowed.txt <- a route of the same name also exists
#   $ROOT/conf/config.yml     <- enables Dancer2::Handler::File

my ( $ROOT, $PUBLIC, $CONFDIR, $LOCKED_IS_UNREADABLE );

BEGIN {
    $ROOT   = Path::Tiny->tempdir;    # kept in scope so it outlives the tests
    $PUBLIC = $ROOT->child('public');
    $PUBLIC->mkpath;
    $CONFDIR = $ROOT->child('conf');
    $CONFDIR->mkpath;

    $ROOT->child('secret.txt')->spew_utf8('SECRET');
    $PUBLIC->child('hello.txt')->spew_utf8('HELLO');
    $PUBLIC->child('shadowed.txt')->spew_utf8('FILE-CONTENT');

    my $locked = $PUBLIC->child('locked.txt');
    $locked->spew_utf8('LOCKED');
    chmod 0000, "$locked";

    # Running as root, or on a filesystem that ignores the mode, leaves the
    # file readable and the 403 assertions below meaningless. Ask the
    # filesystem rather than guessing.
    $LOCKED_IS_UNREADABLE = !-r "$locked";

    $CONFDIR->child('config.yml')->spew_utf8( <<"YML" );
logger: "null"
public_dir: "$PUBLIC"
static_handler: 0
route_handlers:
  - - File
    - public_dir: "$PUBLIC"
YML
}

# --- 1. send_file ---------------------------------------------------------

{
    package SendFileApp;
    use Dancer2;
    set logger         => 'null';
    set public_dir     => "$PUBLIC";
    set static_handler => 0;    # keep path 2 out of the way of path 1

    get '/ok'      => sub { send_file('hello.txt') };
    get '/missing' => sub { send_file('nope.txt') };
    get '/locked'  => sub { send_file('locked.txt') };

    # Two flavours of escape. The second one names a file that does not exist
    # either, which is what makes it interesting: containment has to be
    # decided before existence, or this answers 404 and quietly confirms the
    # path was resolved outside the public directory.
    get '/escape'         => sub { send_file('../secret.txt') };
    get '/escape-missing' => sub { send_file('../no-such-file.txt') };

    get '/absolute'        => sub { send_file("$ROOT/secret.txt") };
    get '/system-absolute' => sub {
        send_file( "$ROOT/secret.txt", system_path => 1 );
    };

    get '/named'  => sub { send_file( 'hello.txt', filename => 'renamed.txt' ) };
    get '/inline' => sub {
        send_file(
            'hello.txt',
            filename            => 'r.txt',
            content_disposition => 'inline',
        );
    };

    get '/in-memory' => sub {
        send_file(
            \'IN-MEMORY',
            content_type => 'text/plain',
            filename     => 'mem.txt',
        );
    };

    get '/after' => sub { send_file('hello.txt'); return 'NEVER-REACHED' };
}

subtest 'send_file will not serve a file outside the public directory' => sub {
    my $test = Plack::Test->create( SendFileApp->to_app );

    # The control: the very same call does serve a file that is inside.
    my $ok = $test->request( GET '/ok' );
    is( $ok->code,    200,     'a file inside the public directory is served' );
    is( $ok->content, 'HELLO', 'and its content is what is on disk' );

    my $escape = $test->request( GET '/escape' );
    is( $escape->code, 403,
        'a ../ path pointing outside the public directory is refused' );
    is( $escape->content, 'Forbidden', 'with the standard 403 body' );
    unlike( $escape->content, qr/SECRET/,
        'and no part of the target file is disclosed' );

    is( $test->request( GET '/escape-missing' )->code, 403,
        'containment is decided before existence, so an escape to a missing file is still 403, not 404' );

    is( $test->request( GET '/absolute' )->code, 403,
        'an absolute path is refused too, unless system_path says otherwise' );

    my $system = $test->request( GET '/system-absolute' );
    is( $system->code, 200,
        'system_path => 1 is the documented way out and still works' );
    is( $system->content, 'SECRET', 'and it does read the requested file' );
};

subtest 'send_file distinguishes missing from unreadable' => sub {
    my $test = Plack::Test->create( SendFileApp->to_app );

    my $missing = $test->request( GET '/missing' );
    is( $missing->code,    404,         'a missing file is a 404' );
    is( $missing->content, 'Not Found', 'with the standard 404 body' );

  SKIP: {
        skip 'cannot make a file unreadable here', 2
            if !$LOCKED_IS_UNREADABLE;

        my $locked = $test->request( GET '/locked' );
        is( $locked->code, 403,
            'a file that exists but cannot be read is a 403, not a 404' );
        is( $locked->content, 'Forbidden', 'with the standard 403 body' );
    }
};

subtest 'send_file sets Content-Disposition and ends the route' => sub {
    my $test = Plack::Test->create( SendFileApp->to_app );

    is( $test->request( GET '/ok' )->header('Content-Disposition'), undef,
        'no Content-Disposition unless a filename was asked for' );

    is(
        $test->request( GET '/named' )->header('Content-Disposition'),
        'attachment; filename="renamed.txt"',
        'a filename produces an attachment disposition under the given name',
    );

    is(
        $test->request( GET '/inline' )->header('Content-Disposition'),
        'inline; filename="r.txt"',
        'content_disposition overrides the attachment default',
    );

    my $mem = $test->request( GET '/in-memory' );
    is( $mem->code,    200,         'a scalar reference is served as content' );
    is( $mem->content, 'IN-MEMORY', 'and the content is the referenced string' );
    is(
        $mem->header('Content-Disposition'),
        'attachment; filename="mem.txt"',
        'an in-memory body can still be given a download filename',
    );

    # send_file longjmps out of the route. If it ever stops doing that, the
    # return value below wins instead.
    is( $test->request( GET '/after' )->content, 'HELLO',
        'send_file exits the route immediately; code after it does not run' );
};

# --- 2. the default static handler ---------------------------------------

{
    package StaticApp;
    use Dancer2;
    set logger     => 'null';
    set public_dir => "$PUBLIC";

    # Both of these are shadowed by a file on disk / by nothing on disk.
    # Which one wins is the behavior being pinned.
    get '/shadowed.txt' => sub { 'ROUTE-CONTENT' };
    get '/nothere.txt'  => sub { 'ROUTE-SERVED-INSTEAD' };
}

subtest 'the default static handler runs ahead of the application' => sub {
    my $test = Plack::Test->create( StaticApp->to_app );

    my $hello = $test->request( GET '/hello.txt' );
    is( $hello->code,    200,     'an existing file is served' );
    is( $hello->content, 'HELLO', 'straight off disk' );
    like( $hello->header('Content-Type'), qr{^text/plain\b},
        'with a content type derived from the extension' );
    like( $hello->header('Content-Type'), qr/charset=utf-8/i,
        'and a charset, because it is a text type' );

    # This is the ordering assertion: the static handler is middleware, so it
    # wins over a route of the same path.
    is( $test->request( GET '/shadowed.txt' )->content, 'FILE-CONTENT',
        'a file on disk beats a route of the same path' );

    # And this is the fall-through: no file, so the request reaches the app.
    my $fell = $test->request( GET '/nothere.txt' );
    is( $fell->code, 200,
        'a missing file does not 404 on the spot' );
    is( $fell->content, 'ROUTE-SERVED-INSTEAD',
        'it falls through to the route that does match' );

    my $escape = $test->request( HTTP::Request->new( GET => '/../secret.txt' ) );
    is( $escape->code, 403,
        'a ../ path is refused by Plack::App::File before Dancer2 sees it' );
    unlike( $escape->content, qr/SECRET/,
        'and the file outside the public directory is not disclosed' );

  SKIP: {
        skip 'cannot make a file unreadable here', 1
            if !$LOCKED_IS_UNREADABLE;
        is( $test->request( GET '/locked.txt' )->code, 403,
            'an unreadable file is a 403 here too' );
    }
};

subtest 'a null byte in a static path is refused quietly (fixed)' => sub {
    my $test = Plack::Test->create( StaticApp->to_app );

    my @warnings;
    my $res = do {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        $test->request( HTTP::Request->new( GET => "/hello.txt\0.png" ) );
    };

    is( $res->code, 404, 'the request is answered, not aborted' );
    unlike( $res->content, qr/HELLO/,
        'and the file whose name was the prefix is not served' );

    # The static handler's file-existence condition used to hand the raw
    # PATH_INFO to Path::Tiny, which warned "Invalid \0 character in pathname"
    # on every such request -- an attacker-supplied path reaching the log once
    # per request. The condition now refuses a NUL-bearing path before
    # Path::Tiny is asked about it, so the request falls through to the
    # application and 404s exactly as it did, but in silence.
    is( scalar @warnings, 0, 'no warning reaches the log' )
        or diag "unexpected warnings:\n@warnings";
};

# --- 3. Dancer2::Handler::File ------------------------------------------
#
# DANCER_CONFDIR has to be in place while the application below is being
# constructed, and gone again afterwards so nothing else in this file reads
# that config. Both BEGIN blocks run at compile time, in the order written,
# and 'use Dancer2' between them builds the application.

BEGIN { $ENV{DANCER_CONFDIR} = "$CONFDIR" }

{
    package HandlerFileApp;
    use Dancer2;

    # Registered before the handler's own /** route, so this one matches
    # first - the opposite of the middleware case above.
    get '/shadowed.txt' => sub { 'ROUTE-CONTENT' };
}

BEGIN { delete $ENV{DANCER_CONFDIR} }

subtest 'Dancer2::Handler::File serves files as an ordinary route' => sub {
    my $test = Plack::Test->create( HandlerFileApp->to_app );

    my $hello = $test->request( GET '/hello.txt' );
    is( $hello->code,    200,     'the handler serves a file under public_dir' );
    is( $hello->content, 'HELLO', 'with the content from disk' );

    is( $test->request( HTTP::Request->new( HEAD => '/hello.txt' ) )->code,
        200, 'and answers HEAD as well as GET' );

    # It is a route, not middleware, and it is registered last - so a route
    # the developer declared wins even when a file of that name exists.
    is( $test->request( GET '/shadowed.txt' )->content, 'ROUTE-CONTENT',
        'a declared route beats a file of the same name here' );

    # The handler passes rather than answering, which is why this reaches the
    # application's own 404 instead of an empty 200.
    is( $test->request( GET '/nothere.txt' )->code, 404,
        'a missing file is passed on and 404s through the application' );

    is( $test->request( HTTP::Request->new( GET => "/hello.txt\0.png" ) )->code,
        400, 'a NUL in the path is rejected outright' );

  SKIP: {
        skip 'cannot make a file unreadable here', 1
            if !$LOCKED_IS_UNREADABLE;
        is( $test->request( GET '/locked.txt' )->code, 403,
            'an unreadable file is a 403' );
    }
};

subtest 'Dancer2::Handler::File refuses a ../ path outside public_dir (fixed)' => sub {

    # This used to be a security hole: Dancer2::Handler::File joined
    # public_dir with the request path and never checked that the result was
    # still inside public_dir. It now resolves the joined path with realpath
    # and applies the same containment check send_file already used at
    # Dancer2/Core/App.pm:1180-1182 ($dir->realpath->subsumes($file_path)),
    # so it agrees with send_file and with Plack::App::File on the default
    # static path, both of which answer 403 for the same request.

    my $test = Plack::Test->create( HandlerFileApp->to_app );

    my $res = $test->request( HTTP::Request->new( GET => '/../secret.txt' ) );

    is( $res->code, 403,
        'a ../ path escaping public_dir is refused' );
    unlike( $res->content, qr/SECRET/,
        'and the content of the file outside public_dir is not disclosed' );
};

subtest 'the ../ escape is refused at any depth (fixed)' => sub {

    # The subtest above pins that a single ../ is refused. This one pins that
    # the containment check holds regardless of how many ../ segments are
    # used - including a surplus that would collapse at the filesystem root -
    # so there is no depth an attacker can use to get back in.
    #
    # Same fix as above - $dir->realpath->subsumes($file_path), the check
    # send_file already makes at Dancer2/Core/App.pm:1182.
    #
    # Note this matters only where the default static handler is off: with it
    # on, Plack::App::File refuses the same request with a 403 before Dancer2
    # ever sees it, which the StaticApp subtest above pins. HandlerFileApp
    # sets static_handler: 0.

    my $test = Plack::Test->create( HandlerFileApp->to_app );

    # Two levels up and back down again, rather than the single ../ above:
    # public_dir/../../<tempdir name>/secret.txt resolves to the same file.
    my $updown = $test->request( HTTP::Request->new(
        GET => '/../../' . $ROOT->basename . '/secret.txt' ) );
    is( $updown->code, 403,
        'a two-level ../../ path is refused just as well as one' );
    unlike( $updown->content, qr/SECRET/,
        'and the file outside public_dir is not disclosed' );

    # More ../ than there are directories: the surplus would otherwise
    # collapse at the filesystem root instead of failing, so this checks the
    # containment guard holds even when an attacker has no knowledge of how
    # deep public_dir happens to sit. $ROOT->relative('/') then walks back
    # down to the fixture from /.
    my $deep = $test->request( HTTP::Request->new(
        GET => '/' . ( '../' x 20 ) . $ROOT->relative('/') . '/secret.txt' ) );
    is( $deep->code, 403,
        'surplus ../ segments are refused rather than collapsing at /' );
    unlike( $deep->content, qr/SECRET/,
        'so the escape does not work regardless of the depth used' );

    # The reason the two assertions above matter: the same shape would
    # otherwise reach a real file outside the application entirely. Guarded,
    # because a readable /etc/passwd is a Unix assumption and this suite also
    # runs on Windows.
  SKIP: {
        skip 'no readable /etc/passwd on this platform', 2
            if !-r '/etc/passwd';

        my $passwd = $test->request( HTTP::Request->new(
            GET => '/' . ( '../' x 20 ) . 'etc/passwd' ) );
        is( $passwd->code, 403,
            '/etc/passwd is refused, not served, through Dancer2::Handler::File' );
        unlike( $passwd->content, qr/^root:/m,
            'and the response is not the system password file' );
    }
};

done_testing();
