use strict;
use warnings;

use Test::More tests => 12;

BEGIN {
    use_ok 'Dancer2::Core::MIME';
}

my $mime = Dancer2::Core::MIME->new();

is_deeply( $mime->custom_types, {}, 'user defined mime_types are empty' );

$mime->add_type( foo => 'text/foo' );
is_deeply( $mime->custom_types, { foo => 'text/foo' }, 'text/foo is saved' );
is( $mime->for_name('foo'), 'text/foo', 'mime type foo is found' );

$mime->add_alias( bar => 'foo' );
is( $mime->for_name('bar'), 'text/foo', 'mime type bar is found' );

is( $mime->for_file('foo.bar'),
    'text/foo', 'mime type for extension .bar is found'
);

is( $mime->for_file('foobar'),
    $mime->default, 'mime type for no extension is the default'
);

is( $mime->add_alias( xpto => 'BAR' ),
    'text/foo', 'mime gets correctly lowercased for user types'
);

is $mime->add_alias( xpto => 'SVG' ) => 'image/svg+xml',
  'mime gets correctly lowercased for system types';

is $mime->add_alias( zbr => 'baz' ) => $mime->default,
  'alias of unknown mime type gets default mime type';

is $mime->name_or_type("text/zbr") => "text/zbr",
  'name_or_type does not change if it seems a mime type string';

is $mime->name_or_type("svg") => "image/svg+xml", 'name_or_type knows svg';
