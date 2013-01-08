# session_object.t

use strict;
use warnings;
use Test::More;

use Dancer::Core::Session;
use Dancer::SessionFactory::Simple;

my $ENGINE = Dancer::SessionFactory::Simple->new;

subtest 'session attributes' => sub {
    my $s1 = $ENGINE->create;

    my $id = $s1->id;
    ok defined($id), 'id is defined';

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
