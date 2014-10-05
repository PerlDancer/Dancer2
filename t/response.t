use strict;
use warnings;
use Test::More import => ['!pass'];
use Dancer2;
use Dancer2::Core::Response;

my $r = Dancer2::Core::Response->new( content => "hello" );
is $r->status,  200;
is $r->content, 'hello';

note "content_type";
$r = Dancer2::Core::Response->new(
    headers => [ 'Content-Type' => 'text/html' ],
    content => 'foo',
);

is_deeply $r->to_psgi,
  [ 200,
    [   Server         => "Perl Dancer2 $Dancer2::VERSION",
        'Content-Type' => 'text/html',
    ],
    ['foo']
  ];

isa_ok $r->headers,  'HTTP::Headers';
is $r->content_type, 'text/html';

$r->content_type('text/plain');
is $r->content_type, 'text/plain';

ok( !$r->is_forwarded );
$r->forward('http://perldancer.org');
ok( $r->is_forwarded );

is $r->header('X-Foo'), undef;

$r->header( 'X-Foo' => 42 );
is $r->header('X-Foo'), 42;

$r->header( 'X-Foo' => 432 );
is $r->header('X-Foo'), 432;

$r->push_header( 'X-Foo' => 777 );
is $r->header('X-Foo'), '432, 777';

$r->header( 'X-Bar' => 234 );
is $r->header('X-Bar'),      '234';
is $r->push_header('X-Bar'), '234';

is scalar( @{ $r->headers_to_array } ), 10;

# stringify HTTP status
$r = Dancer2::Core::Response->new( content => "foo", status => "Not Found" );
is $r->status, 404;

$r =
  Dancer2::Core::Response->new( content => "foo", status => "not_modified" );
is $r->status, 304;

done_testing;
