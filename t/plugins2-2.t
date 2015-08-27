use strict;
use warnings;

use lib 't/lib';

use poc2;
use Test::More tests => 6;

use Test::WWW::Mechanize::PSGI;

 my $mech = Test::WWW::Mechanize::PSGI->new(
          app =>  poc2->to_app
      );

$mech->get_ok( '/' );
$mech->content_like( qr'please' );
$mech->content_like( qr'8-D' );

$mech->get_ok('/goodbye');

$mech->content_like( qr/farewell/ );
$mech->content_like( qr'please' );
