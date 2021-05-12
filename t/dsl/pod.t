use strict;
use warnings;
use Test::More;

use Dancer2::Core::DSL;
use Pod::Simple::SimpleTree;

{
    package App;
    use Dancer2;
}

my $dsl_keywords = Dancer2::Core::DSL->new(app => App->to_app)->dsl_keywords;

isa_ok($dsl_keywords, 'HASH', 'Check whether keywords are present');

my $podpa = Pod::Simple::SimpleTree->new->parse_file('lib/Dancer2/Manual/Keywords.pod')->root;

my $in_section = 0;

for my $entry (@$podpa) {
    if (ref($entry) eq 'ARRAY') {
        if ($entry->[0] eq 'head1') {
            if ($entry->[2] eq 'DSL KEYWORDS') {
                # keywords following that entry
                $in_section = 1;
            }
            elsif ($in_section == 1) {
                # end of keywords section
                last;
            }
        }

        if ($in_section && $entry->[0] eq 'head2') {
            # get the bare keyword and compare with the authoritative list
            my $title = $entry->[2];
            $title =~ /^\s*(\S+)/;
            my $keyword = $1;

            if (exists $dsl_keywords->{$keyword}) {
                $dsl_keywords->{$keyword}->{found} = $entry->[1]->{startline};
            }
        }
    }
}

# go through the authoritative list and test we have a corresponding POD entry
for my $keyword ( sort keys %$dsl_keywords ) { 
    ok( exists $dsl_keywords->{$keyword}->{found}, "Keyword $keyword is documented in Dancer2::Manual::Keywords" );
}

done_testing;
