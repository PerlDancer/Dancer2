use strict;
use warnings;

use Test::More;
use File::Temp qw< tempdir >;
use Path::Tiny qw< path >;
use Capture::Tiny qw< capture >;
use Config;
use File::Which qw< which >;
use TAP::Harness;

# End-to-end test for the `dancer2 gen` scaffold: it runs the real command as a
# separate process against share/skel, then compiles and runs what came out.
#
# It runs the command out of *this* source tree, never an installed Dancer2:
#   -s share/skel  points at the skeleton in the repo rather than the dist_dir
#   -x             skips the "is there a newer Dancer2 on CPAN?" check, which
#                  needs the network and warns when it cannot reach it -- but
#                  only if this build still has that option, see below
# The generated application only knows about Dancer2 through PERL5LIB, which is
# set to this repo's lib for every child process below.

my $repo   = path('.')->absolute;
my $script = $repo->child('script/dancer2');
my $skel   = $repo->child('share/skel');

-f $script && -d $skel
    or plan skip_all => 'must be run from the distribution root';

my $lib = $repo->child('lib')->stringify;

# Whether the generator understands -x has to be asked, not assumed. Debian
# patches the CPAN version check out of Dancer2::CLI::Gen as a privacy measure
# (debian/patches/no-phone-home.patch), and the option whose only job is to
# switch that check off goes with it, so on a build made from those sources
# passing -x aborts the generator with "Unknown option: x" before it writes a
# single file -- and every assertion in this file then fails, pointing at the
# scaffold rather than at the flag. Where the option is gone, so is the network
# access it exists to suppress, so dropping it loses nothing.
my @no_check = _no_check_option();

# Ask the command itself what it accepts. Osprey spells the long form with
# dashes or underscores depending on its version, so match the short form, and
# accept either spelling of the long one.
sub _no_check_option {
    my ( $stdout, $stderr ) = capture {
        local $ENV{'PERL5LIB'} = _prepend_lib();
        system( $Config{'perlpath'}, "-I$lib", "$script", 'gen', '--help' );
    };

    my $usage = "$stdout$stderr";
    return '-x' if $usage =~ /(?:^|\s)-x\b/ || $usage =~ /--no.check\b/;

    note 'this dancer2 gen has no -x: running without it, on the assumption '
        . 'that the version check it skips has been patched out too';
    return;
}

# Run the generator. Returns the exit status and both output streams; the
# generator is chatty on STDOUT ("+ path" per file written), and none of that
# should reach this suite's own output.
sub gen {
    my @args = @_;
    my ( $stdout, $stderr, $status ) = capture {
        local $ENV{'PERL5LIB'} = _prepend_lib();
        system( $Config{'perlpath'}, "-I$lib", "$script", 'gen',
            '-s', "$skel", @no_check, '--overwrite', @args );
    };
    return {
        status => $status,
        stdout => $stdout,
        stderr => _without_version_check_warning($stderr),
    };
}

# With no -x to pass, a build that kept the version check runs it, and it warns
# when it cannot reach metacpan -- which is the normal state of a package build
# daemon. That warning is the generator saying something this test has no way
# to switch off in such a build, so it is dropped here rather than failing the
# "says nothing on STDERR" assertion. Only those two lines go; anything else
# the generator writes to STDERR is still caught. Builds that do have -x are
# left alone, so the assertion stays strict where it can be.
sub _without_version_check_warning {
    my $stderr = shift;
    return $stderr if @no_check;
    $stderr =~ s{\s*Couldn't determine latest version of Dancer2\b[^\n]*\n[^\n]*\n\s*}{}s;
    return $stderr;
}

# This repo's lib has to come first so the child sees *this* Dancer2, but it
# must not replace whatever PERL5LIB already carries -- under local::lib (as
# used in development and CI) that variable is how the child finds Dancer2's
# own dependencies (e.g. CLI::Osprey), and clobbering it makes every child
# process below fail before it even gets to the code under test.
sub _prepend_lib {
    return join $Config{'path_sep'}, $lib,
        ( defined $ENV{'PERL5LIB'} && length $ENV{'PERL5LIB'} ? $ENV{'PERL5LIB'} : () );
}

# Read a generated file, or give back the empty string if the generator never
# wrote it. A missing file is already reported by the file-presence subtest;
# this keeps the content assertions from dying and taking the rest of the run
# down with them, so one broken thing produces one clear list of failures.
sub slurp {
    my $file = shift;
    return $file->is_file ? $file->slurp_utf8 : '';
}

# The application the scaffold has to produce, listed here rather than derived
# from share/skel -- deriving it would make the check vacuous, since a file
# deleted from the skeleton would also vanish from the expectation. Every entry
# is something the generated app needs to start, serve its one route, or be
# packaged.
my @required = qw<
    bin/app.psgi
    config.yml
    cpanfile
    views/index.tt
    views/layouts/main.tt
    public/404.html
    public/500.html
    public/css/style.css
    public/dispatch.cgi
    public/dispatch.fcgi
    t/001_base.t
    t/002_index_route.t
    environments/development.yml
    environments/production.yml
    .dancer
    Makefile.PL
    MANIFEST
    MANIFEST.SKIP
>;

my $tmp = tempdir( CLEANUP => 1 );
my $run = gen( '-a', 'MyApp::App', '-d', 'myapp', '--path', $tmp );
my $app = path( $tmp, 'myapp' );

subtest 'the generator runs cleanly and writes where it was told' => sub {
    is( $run->{'status'}, 0, 'dancer2 gen exits successfully' )
        or diag "STDERR:\n$run->{stderr}\nSTDOUT:\n$run->{stdout}";
    is( $run->{'stderr'}, '', 'and says nothing on STDERR' );

    ok( $app->is_dir, "--path and -d put the application in $app" );
    like( $run->{'stdout'}, qr/Your new application is ready/,
        'the run ends with the how-to-run banner' );
};

subtest 'every file the generated application needs is present' => sub {
    # This is the subtest that goes red if share/skel loses something.
    for my $file (@required) {
        ok( $app->child($file)->is_file, "generated $file" );
    }

    # The skeleton marks these two with a leading '+' to request the exec bit;
    # the '+' must not survive into the generated name.
    ok( !$app->child('bin/+app.psgi')->exists,
        'the + marker is stripped from the generated filename' );

    SKIP: {
        skip 'no meaningful exec bit on this platform', 2
            if $^O eq 'MSWin32';
        ok( -x $app->child('bin/app.psgi')->stringify,
            'bin/app.psgi is executable' );
        ok( -x $app->child('public/dispatch.cgi')->stringify,
            'public/dispatch.cgi is executable' );
    }
};

subtest '-a decides the package name and the module path' => sub {
    my $module = $app->child('lib/MyApp/App.pm');
    ok( $module->is_file, 'the module is written at the path -a implies' );

    my $source = slurp($module);
    like( $source, qr/^package MyApp::App;/m, 'and declares that package' );
    ok( length $source && $source !~ /AppFile/,
        'no trace of the skeleton\'s placeholder package name' );

    # The same name has to reach the files that refer to the app by name, or
    # the generated app starts but cannot be packaged or served.
    like( slurp( $app->child('bin/app.psgi') ), qr/\buse MyApp::App\b/,
        'the .psgi entry point loads the generated module' );
    like( slurp( $app->child('Makefile.PL') ), qr/NAME\s*=>\s*'MyApp::App'/,
        'Makefile.PL names the generated module' );

    # Template tokens are [d2% ... %2d]; any left behind means a variable was
    # never substituted.
    for my $file (qw< bin/app.psgi Makefile.PL config.yml >) {
        my $content = slurp( $app->child($file) );
        ok( length $content && $content !~ /\Q[d2%\E/,
            "no unsubstituted template token left in $file" );
    }
};

subtest 'the generated application compiles' => sub {
    my ( $stdout, $stderr, $status ) = capture {
        system( $Config{'perlpath'}, "-I$lib",
            '-I' . $app->child('lib')->stringify,
            '-c', $app->child('lib/MyApp/App.pm')->stringify );
    };

    is( $status, 0, 'perl -c on the generated module succeeds' )
        or diag "STDERR:\n$stderr";
    like( $stderr, qr/syntax OK/, 'and perl says so' );
};

subtest 'the generated application passes its own bundled tests' => sub {
    # The app's tests are run from inside the generated directory, the way its
    # author would run them. Using TAP::Harness (rather than shelling out to
    # prove) ensures the child perls are invoked via $^X -- the same interpreter
    # that is running this test suite -- so they see the same @INC and the same
    # XS extensions. Shelling out to prove lets PATH decide which perl to use,
    # which on smokers with multiple perls installed can differ from this one,
    # producing "Can't locate Module::Runtime" or XS handshake mismatches.
    my ( $stdout, $stderr, $status ) = capture {
        local $ENV{'PERL5LIB'} = _prepend_lib();
        my $cwd = path('.')->absolute;
        chdir $app->stringify or die "cannot chdir to $app: $!";
        my $harness = TAP::Harness->new({ lib => ['lib'] });
        my $aggregator = $harness->runtests(glob 't/*.t');
        chdir $cwd->stringify or die "cannot chdir back to $cwd: $!";
        $aggregator->has_errors ? 1 : 0;
    };

    is( $status, 0, 'the generated app passes its own tests' )
        or diag "STDOUT:\n$stdout\nSTDERR:\n$stderr";
    like( $stdout, qr/Result: PASS/, 'the harness agrees' );
};

subtest 'the application directory is named after the dashed app name (fixed)' => sub {
    # This used to leave the directory named after the application verbatim --
    # colons and all -- even though the generator computes a dashed name for
    # exactly this purpose. Without -d, that dashed name is now what the
    # directory option falls back to, so the directory and the Makefile.PL it
    # contains agree with each other.
    my $dir = tempdir( CLEANUP => 1 );
    my $res = gen( '-a', 'Other::App', '--path', $dir );

    is( $res->{'status'}, 0, 'generating without -d still succeeds' );
    ok( path( $dir, 'Other-App' )->is_dir,
        'the directory is named Other-App, dashed' );
    ok( !path( $dir, 'Other::App' )->exists,
        'and the raw, colon-bearing name is not used' );

    # The dashed name also reaches the generated Makefile.PL -- the two
    # spellings inside one generated application now agree.
    like(
        slurp( path( $dir, 'Other-App', 'Makefile.PL' ) ),
        qr/FILES\s*=>\s*'Other-App-\*'/,
        'and Makefile.PL cleans the same dashed name',
    );

    # An explicit -d must still be honoured verbatim -- the fallback only
    # kicks in when the option is absent -- so the directory that appears has
    # to be the one that was asked for, not the dashed name. The name used
    # here is one Windows can put on disk, so this runs everywhere; the
    # colon-bearing spelling of the same thing, which is what makes the point
    # most sharply, is checked below where such a directory can exist at all.
    my $res2 = gen( '-a', 'Other::App', '-d', 'Other_App', '--path', $dir );
    is( $res2->{'status'}, 0, 'generating with an explicit -d still succeeds' )
        or diag "STDERR:\n$res2->{stderr}\nSTDOUT:\n$res2->{stdout}";
    ok( path( $dir, 'Other_App' )->is_dir,
        'and an explicit -d is honoured verbatim, not dashed' );

  SKIP: {
        # ':' is not a legal character in a Windows file name at all - it
        # introduces an alternate data stream - so no Windows file system can
        # hold a directory called Other::App, and a generator asked to make
        # one there can only fail. The dashes this used to be checked through
        # are checked above instead; this is the original spelling.
        skip 'Windows cannot put a colon in a directory name', 2
            if $^O eq 'MSWin32';

        my $res3 = gen( '-a', 'Other::App', '-d', 'Other::App', '--path', $dir );
        is( $res3->{'status'}, 0, 'a colon-bearing -d still succeeds' )
            or diag "STDERR:\n$res3->{stderr}\nSTDOUT:\n$res3->{stdout}";
        ok( path( $dir, 'Other::App' )->is_dir,
            'and is honoured verbatim, even with colons in it' );
    }
};

subtest 'MANIFEST.SKIP gets the relative dashed name (fixed)' => sub {
    # This used to build the appended line from the full filesystem path the
    # app was generated into, so it could never match anything -- MANIFEST.SKIP
    # patterns are matched against distribution-root-relative paths. The line
    # is now the dashed distribution name, matching what Makefile.PL cleans.
    my @lines = split /\n/, slurp( $app->child('MANIFEST.SKIP') );
    my $appended = @lines ? $lines[-1] : '';

    is( $appended, '^MyApp-App-', 'the appended pattern is the relative dashed name' );
    unlike( $appended, qr{^\^/}, 'and is not anchored to an absolute filesystem path' );

    # No line in the file should carry an absolute path -- that was the shape
    # of the bug, so make sure it is gone everywhere, not just the last line.
    ok( !( grep { m{^\^?/} } @lines ), 'no line in MANIFEST.SKIP is an absolute path' );

    # The rest of the file is what a MANIFEST.SKIP is supposed to look like,
    # which is what makes the appended line fit in rather than stand out.
    ok( ( grep { $_ eq '^\.gitignore' || $_ eq '^.gitignore' } @lines ),
        'the other patterns are relative, as MANIFEST.SKIP expects' );
};

subtest 'the skeleton environment configs are in git (fixed)' => sub {
    # This was caused by share/.gitignore: shipped as data -- Dancer2::CLI::Gen
    # copies it into a generated app when -g is given -- but because it sat
    # inside share/ under that name, git also applied its patterns to this
    # repository's own tree, and one of them was 'environments/'. That template
    # now lives at share/gitignore instead (a name git does not honour as an
    # ignore file), so the skeleton's environment configs can be committed, and
    # a fresh clone generates them. They also belong in @required above now.
    my $probe = 'share/skel/default/environments/development.yml';

    # Being inside a work tree is not enough. 'dzil test' builds into
    # .build/XXXX *within* this checkout and runs the suite from there, so
    # --is-inside-work-tree succeeds while 'git ls-files <path>' -- which
    # resolves its pathspec relative to the current directory -- names a
    # build artifact rather than the source file, and reports nothing.
    # Ask git where the top of the tree is and query from there instead,
    # skipping where there is no git at all (a released tarball on a smoker).
    my ( $toplevel, undef, $rev_status ) = capture {
        system( 'git', 'rev-parse', '--show-toplevel' );
    };
    $rev_status == 0
        or plan skip_all => 'not a git checkout, so tracking cannot be checked';
    chomp $toplevel;

    -d path( $toplevel, 'share/skel/default' )
        or plan skip_all => "git top level $toplevel is not this source tree";

    my ($tracked) = capture {
        system( 'git', '-C', $toplevel, 'ls-files',
                'share/skel/default/environments' );
    };
    like( $tracked, qr{development\.yml}, 'development.yml is tracked by git' );
    like( $tracked, qr{production\.yml}, 'production.yml is tracked by git' );

    # And the generator actually produced them for the app built at the top of
    # this file -- already covered by @required above, but asserted here too
    # since this is the subtest that explains why.
    ok( $app->child('environments/development.yml')->is_file,
        'environments/development.yml is generated' );
    ok( $app->child('environments/production.yml')->is_file,
        'environments/production.yml is generated' );
};

subtest '-g creates a git repository with an initial commit (fixed)' => sub {
    # _check_git used to die with "Can't locate object method \"absolute\"
    # via package ..." -- it called ->absolute on $vars->{apppath}, a plain
    # string, instead of using $vars->{appdir}, which run() had already made
    # absolute for exactly this purpose. That happened after the application
    # was written but before git ever ran, so the user was left with a
    # generated app, no repository, and a stack-shaped error instead of the
    # how-to-run banner. -r implies -g and shares the same code path, so a
    # working -g is what -r's remote-adding also depends on.
    which('git')
        or plan skip_all => 'no usable git binary found';

    my $dir = tempdir( CLEANUP => 1 );

    # git needs a name and email to commit, and may consult other bits of
    # config (e.g. commit.gpgsign) that vary developer to developer and could
    # make this hang or fail for reasons that have nothing to do with the code
    # under test. Rather than rely on -- or fight with -- whatever is in the
    # developer's own ~/.gitconfig, give the child processes below a HOME of
    # their own (so no global or user config is read at all) and supply the
    # commit identity git itself reads via the environment.
    my $git_home = tempdir( CLEANUP => 1 );
    local $ENV{'HOME'}               = $git_home;
    local $ENV{'XDG_CONFIG_HOME'}    = $git_home;
    local $ENV{'GIT_AUTHOR_NAME'}    = 'Dancer2 Test Suite';
    local $ENV{'GIT_AUTHOR_EMAIL'}   = 'dancer2-tests@example.invalid';
    local $ENV{'GIT_COMMITTER_NAME'} = 'Dancer2 Test Suite';
    local $ENV{'GIT_COMMITTER_EMAIL'} = 'dancer2-tests@example.invalid';

    my $res    = gen( '-a', 'Git::App', '-d', 'gitapp', '--path', $dir, '-g' );
    my $gitapp = path( $dir, 'gitapp' );

    is( $res->{'status'}, 0, 'dancer2 gen -g exits successfully' )
        or diag "STDERR:\n$res->{stderr}\nSTDOUT:\n$res->{stdout}";
    like( $res->{'stdout'}, qr/Your new application is ready/,
        'and still ends with the how-to-run banner, not a stack trace' );

    ok( $gitapp->child('.git')->is_dir, 'a git repository was created' );

    my $git_dir = $gitapp->child('.git')->stringify;
    my ( $log, undef, $log_status ) = capture {
        system( 'git', '--git-dir', $git_dir, 'log', '--oneline' );
    };
    is( $log_status, 0, 'the repository has at least one commit' );
    like( $log, qr/Initial commit of Git::App by Dancer2/,
        'and it is the generator\'s initial commit' );

    my ( $tracked, undef, $ls_status ) = capture {
        system( 'git', '--git-dir', $git_dir, '--work-tree', $gitapp->stringify,
            'ls-files' );
    };
    is( $ls_status, 0, 'can list the files the initial commit contains' );
    like( $tracked, qr{bin/app\.psgi}, 'the generated application files are in it' );
    like( $tracked, qr{lib/Git/App\.pm}, 'including the generated module' );
};

done_testing();
