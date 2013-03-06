use strict;
use warnings;

use Test::More;

use Dancer2;

# testing default values
is(setting('port'), '3000', "default value for 'port' is OK");
is(setting('content_type'), 'text/html',
    "default value for 'content_type' is OK");

#should we test for all default values?


# testing new settings
ok(setting('foo' => '42'), 'setting a new value');
is(setting('foo'), 42, 'new value has been set');

# test the alias 'set'
ok(set(bar => 43), 'setting bar with set');
is(setting('bar'), 43, 'new value has been set');

#multiple values
ok(setting('foo' => 43, bar => 44), 'set multiple values');
ok(setting('foo') == 43 && setting('bar') == 44,
    'set multiple values successful');

done_testing;
