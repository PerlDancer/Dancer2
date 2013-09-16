# session_object.t

use strict;
use warnings;
use Test::More;
use Test::Fatal;

use Dancer2::Core::Session;
use Dancer2::Session::Simple;
use Class::Load 'try_load_class';

my $ENGINE = Dancer2::Session::Simple->new;

my $CPRNG_AVAIL = try_load_class('Math::Random::ISAAC::XS')
  && try_load_class('Crypt::URandom');

diag $CPRNG_AVAIL
  ? "Crypto strength tokens"
  : "Default strength tokens";

subtest 'session attributes' => sub {
    my $s1 = $ENGINE->create;

    my $id = $s1->id;
    ok defined($id), 'id is defined';
    is(exception { $s1->id("new_$id") }, undef, 'id can be set');
    is($s1->id, "new_$id", '... new value found for id');

    my $s2 = $ENGINE->create;
    isnt($s1->id, $s2->id, "IDs are not the same");
};

my $count = 10_000;
subtest "$count session IDs and no dups" => sub {
    my $seen      = {};
    my $iteration = 0;
    foreach my $i (1 .. $count) {
        my $s1 = $ENGINE->create;
        my $id = $s1->id;
        if (exists $seen->{$id}) {
            last;
        }
        $seen->{$id} = 1;
        $iteration++;
    }

    is $iteration, $count,
      "no duplicate ID after $count iterations (done $iteration)";
};

done_testing;
