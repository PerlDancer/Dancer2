#!/usr/bin/env perl

use strict;

BEGIN {
    $|  = 1;
    $^W = 1;
}
use Test::More tests => 6;
use Dancer2::Template::Implementation::ForkedTiny ();

sub preprocess {
    my $template = $_[0];
    my $expected = $_[1];
    my $message  = $_[2] || 'Template preprocessd ok';
    my $prepared =
      Dancer2::Template::Implementation::ForkedTiny->new->preprocess(
        $template);
    is( $prepared, $expected, $message );
    is( $template, $_[0],
        '->proprocess does not modify original template variable'
    );
}


######################################################################
# Main Tests

preprocess( <<'END_TEMPLATE', <<'END_EXPECTED', 'Simple IF' );
foo
[% IF foo %]
foobar
[% END %]
bar
END_TEMPLATE
foo
[% I1 foo %]
foobar
[% I1 %]
bar
END_EXPECTED

preprocess( <<'END_TEMPLATE', <<'END_EXPECTED', 'Simple UNLESS' );
foo
[% UNLESS foo %]
foobar
[% END %]
bar
END_TEMPLATE
foo
[% U1 foo %]
foobar
[% U1 %]
bar
END_EXPECTED

preprocess( <<'END_TEMPLATE', <<'END_EXPECTED', 'Simple FOREACH' );
foo
[% FOREACH element IN lists %]
foobar
[% END %]
bar
END_TEMPLATE
foo
[% F1 element IN lists %]
foobar
[% F1 %]
bar
END_EXPECTED
