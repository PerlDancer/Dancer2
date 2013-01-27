#!/usr/bin/perl

use strict;

BEGIN {
    $|  = 1;
    $^W = 1;
}
use Test::More tests => 1;
use Dancer::Template::Implementation::ForkedTiny ();

sub process {
    my $stash    = shift;
    my $input    = shift;
    my $expected = shift;
    my $message  = shift || 'Template processed ok';
    my $output   = '';
    Dancer::Template::Implementation::ForkedTiny->new->process(\$input,
        $stash, \$output);
    is($output, $expected, $message);
}


######################################################################
# Main Tests

process({foo => 'World'}, <<'END_TEMPLATE', <<'END_EXPECTED', 'Trivial ok');
Hello [% foo %]!
END_TEMPLATE
Hello World!
END_EXPECTED
