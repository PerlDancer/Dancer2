use strict;
use warnings;
use Path::Tiny qw(cwd path);
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

    my $path = path(qw< t classes Dancer2-Core-Role-HasLocation with.t >);

    is(
        path($app->caller)->canonpath,
        $path->canonpath,
        'Default caller',
    );

}

my $basedir = path(__FILE__)->realpath->parent;

note 'With lib/ and bin/:'; {
    my $app = App->new(
        caller =>
          $basedir->child(qw<FakeDancerDir lib fake inner dir fakescript.pl>)
          ->canonpath
    );

    isa_ok( $app, 'App' );

    my $path = cwd->absolute->child(
        qw<t classes Dancer2-Core-Role-HasLocation FakeDancerDir>);

    is(
        path($app->location)->canonpath,
        $path->canonpath,
        'Got correct location with lib/ and bin/',
    );
}

note 'With .dancer file:'; {
    my $app = App->new(
        caller => $basedir->child(qw<FakeDancerFile script.pl>)->canonpath
    );

    isa_ok( $app, 'App' );

    my $path = cwd->absolute->child(
        qw<t classes Dancer2-Core-Role-HasLocation FakeDancerFile>);

    is(
        path($app->location)->canonpath,
        $path->canonpath,
        'Got correct location with .dancer file'
    );
}

note 'blib/ ignored:'; {
    my $app = App->new(
        caller =>
          $basedir->child(qw<FakeDancerDir blib lib fakescript.pl>)->canonpath
    );

    isa_ok( $app, 'App' );

    my $path = cwd->absolute->child(
        qw<t classes Dancer2-Core-Role-HasLocation FakeDancerDir>);

    is(
        path($app->location)->canonpath,
        $path->canonpath,
        'blib/ dir is ignored'
    );
}
