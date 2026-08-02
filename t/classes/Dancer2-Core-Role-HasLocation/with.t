use strict;
use warnings;
use Path::Tiny qw< path >;
use Test::More tests => 19;

{
    package App;
    use Moo;
    with 'Dancer2::Core::Role::HasLocation';
}

note 'Defaults:'; {
    my $app = App->new();
    isa_ok( $app, 'App' );
    can_ok( $app, qw<caller location> ); # attributes
    can_ok( $app, '_build_location'   ); # methods

    ok(
        $app->DOES('Dancer2::Core::Role::HasLocation'),
        'App consumes Dancer2::Core::Role::HasLocation',
    );

    my $path = path(qw<
        t classes Dancer2-Core-Role-HasLocation with.t
    >)->stringify;

    is(
        path( $app->caller ),
        $path,
        'Default caller',
    );

}

my $basedir = path( __FILE__ )->parent->stringify;

note 'With lib/ and bin/:'; {
    my $app = App->new(
        caller => path(
            $basedir, qw<FakeDancerDir lib fake inner dir fakescript.pl>
        )->stringify
    );

    isa_ok( $app, 'App' );

    my $location = $app->location;
    $location =~ s/\/$//;

    my $path = path(
        qw<t classes Dancer2-Core-Role-HasLocation FakeDancerDir>,
    )->absolute->stringify;

    is(
        $location,
        $path,
        'Got correct location with lib/ and bin/',
    );
}

note 'With .dancer file:'; {
    my $app = App->new(
        caller => path(
            $basedir, qw<FakeDancerFile script.pl>
        )->stringify
    );

    isa_ok( $app, 'App' );

    my $location = $app->location;

    my $path = path(
        qw<t classes Dancer2-Core-Role-HasLocation FakeDancerFile>,
    )->absolute->stringify;

    is( $location, $path, 'Got correct location with .dancer file' );
}

# FakeDistRoot/ has lib/ and bin/, exactly like any Perl distribution root,
# like ~, like /usr and /usr/local. The real app roots are nested inside it.
# Before GH #1781 the upward walk stalled and never noticed FakeDistRoot;
# now that it walks properly, lib/+bin/ must not outrank real Dancer2
# artifacts found closer to the script.
note 'Does not walk past an app root into an enclosing lib/+bin/ dir:'; {
    my %case = (
        't'         => 'config.yml, views/ and public/',
        'configonly' => 'a config file alone',
        'viewsonly'  => 'a views/ directory alone',
    );

    foreach my $dir ( sort keys %case ) {
        my $app = App->new(
            caller => path(
                $basedir, 'FakeDistRoot', $dir, 'fakescript.pl'
            )->stringify
        );

        my $path = path(
            qw<t classes Dancer2-Core-Role-HasLocation FakeDistRoot>, $dir,
        )->absolute->stringify;

        is(
            $app->location,
            $path,
            "App root found by $case{$dir}, not the enclosing lib/+bin/ dir",
        );
    }
}

# A checkout or distribution root is a ceiling: whatever the app root is, it
# sits at or below that line, never in the directory above it. Built at
# runtime rather than shipped, because git will not track a path named .git.
note 'Stops at a project boundary rather than escaping above it:'; {
    my $tmp = Path::Tiny->tempdir;

    # plays the part of a home directory: lib/ and bin/, nothing Dancer2
    $tmp->child($_)->mkpath for qw< lib bin >;

    foreach my $marker ( qw< .git .hg Makefile.PL dist.ini cpanfile > ) {
        my $checkout = $tmp->child("checkout$marker");
        my $srcdir   = $checkout->child('src');
        $srcdir->mkpath;

        # .git and .hg are directories in a normal checkout, the rest files
        $marker =~ /^\./ ? $checkout->child($marker)->mkpath
                         : $checkout->child($marker)->touch;

        my $script = $srcdir->child('fakescript.pl');
        $script->touch;

        my $app = App->new( caller => $script->stringify );

        is(
            $app->location,
            $srcdir->realpath->stringify,
            "$marker halts the walk instead of reaching the lib/+bin/ dir above",
        );
    }
}

note 'blib/ ignored:'; {
    my $app = App->new(
        caller => path(
            $basedir, qw<FakeDancerDir blib lib fakescript.pl>
        )->stringify
    );

    isa_ok( $app, 'App' );

    my $location = $app->location;
    $location =~ s/\/$//;

    my $path = path(
        qw<t classes Dancer2-Core-Role-HasLocation FakeDancerDir>,
    )->absolute->stringify;

    is( $location, $path, 'blib/ dir is ignored' );
}
