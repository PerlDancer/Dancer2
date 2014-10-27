#!perl

use strict;
use warnings;

use File::Spec;
use File::Basename;
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

    is(
        $app->caller,
        't/classes/Dancer2-Core-Role-HasLocation/with.t',
        'Default caller',
    );
}

my $basedir = dirname( File::Spec->rel2abs(__FILE__) );

note 'With lib/ and bin/:'; {
    my $app = App->new(
        caller => File::Spec->catfile(
            $basedir, qw<FakeDancerDir fake inner dir fakescript.pl>
        )
    );

    isa_ok( $app, 'App' );

    my $location = $app->location;
    $location =~ s/\Q$basedir\E//;
    $location =~ s{[\\/]}{}g;

    is(
        $location,
        'FakeDancerDir',
        'Got correct location with lib/ and bin/',
    );
}

note 'With .dancer file:'; {
    my $app = App->new(
        caller => File::Spec->catfile(
            $basedir, qw<FakeDancerFile script.pl>
        )
    );

    isa_ok( $app, 'App' );

    my $location = $app->location;
    $location =~ s/\Q$basedir\E//;
    $location =~ s{[\\/]}{}g;

    is(
        $location,
        'FakeDancerFile',
        'Got correct location with .dancer file',
    );
}

note 'blib/ ignored:'; {
    my $app = App->new(
        caller => File::Spec->catfile(
            $basedir, qw<FakeDancerDir blib lib fakescript.pl>
        )
    );

    isa_ok( $app, 'App' );

    my $location = $app->location;
    $location =~ s/\Q$basedir\E//;
    $location =~ s{[\\/]}{}g;

    is(
        $location,
        'FakeDancerDir',
        'blib/ dir is ignored',
    );
}
