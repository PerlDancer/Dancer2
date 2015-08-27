use strict;
use warnings;

use lib 't/lib';

use poc;
use Test::More tests => 6;

use Test::WWW::Mechanize::PSGI;

 my $mech = Test::WWW::Mechanize::PSGI->new(
          app =>  poc->to_app
      );

$mech->get_ok( '/' );
$mech->content_like( qr'added by plugin' );

$mech->content_like( qr/something:1/, 'config parameters are read' );

$mech->content_like( qr/Bar loaded/, 'Plugin Bar has been loaded' );

$mech->content_like( qr/bazbazbaz/, 'Foo has a copy of Bar' );

$mech->get( '/truncate' );
$mech->content_like( qr'helladd' );
