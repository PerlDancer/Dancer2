use strict;
use warnings;
use Path::Tiny qw< path >;
use Test::More tests => 11;

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
