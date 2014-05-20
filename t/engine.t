use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Dancer2::Core::App;
use Dancer2::Template::Tiny;

my $f = Dancer2::Template::Tiny->new();
isa_ok $f, 'Dancer2::Template::Tiny';
ok( $f->does('Dancer2::Core::Role::Engine') );
ok( $f->does('Dancer2::Core::Role::Template') );

is( $f->name, 'Tiny' );

# checks for validity of engine names

my $app = Dancer2::Core::App->new();
isa_ok( $app, 'Dancer2::Core::App' );

{
    no warnings qw<redefine once>;
    *Dancer2::Core::Factory::create = sub { $_[1] };
}

foreach my $engine_type ( qw<logger session template> ) {
    my $engine;
    my $build_method = "_build_${engine_type}_engine";

    is(
        exception {
            $engine = $app->$build_method(
                undef, { $engine_type => 'Fake43Thing' }
            );
        },
        undef,
        "Built $engine_type successfully",
    );

    like(
        exception {
            $engine = $app->$build_method(
                undef, { $engine_type => '7&&afail' }
            );
        },
        qr/^Cannot load $engine_type engine '7&&afail': illegal module name/,
        "Built $engine_type successfully",
    );

    is( $engine, $engine_type, 'Correct response from override' );
}

done_testing;
