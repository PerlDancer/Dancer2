# session_object.t

use strict;
use warnings;
use Test::More;
use Test::Fatal;

use Dancer2::Core::Session;
use Dancer2::Session::Simple;

my $ENGINE = Dancer2::Session::Simple->new;

my $CPRNG_AVAIL = eval { require Math::Random::ISAAC::XS; 1; }
  && eval { require Crypt::URandom; 1; };

note $CPRNG_AVAIL
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
