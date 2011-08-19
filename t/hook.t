use Test::More;

plan tests => 1;

use strict;
use warnings;

use Dancer::Core::Hook;

my $h = Dancer::Core::Hook->new(name => 'before_template');
is $h->name, 'before_template_render';
