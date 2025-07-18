use strict;
use warnings;
use Test::More;
use Test::WWW::Mechanize::PSGI;

use [d2% appname %2d];
my $mech = Test::WWW::Mechanize::PSGI->new(
    app => [d2% appname %2d]->to_app,
);

$mech->get_ok('/create', 'Got /create while not logged in');
$mech->content_contains('Password', '...and was presented with a login page');
$mech->submit_form_ok({
    fields => {
        username => 'admin',
        password => 'foobar',
    }}, '...which we gave invalid credentials');
$mech->content_contains('Invalid username or password', '...and gave us an appropriate error');
$mech->submit_form_ok({
    fields => {
        username => 'admin',
        password => 'test',
    }}, '...so we give it real credentials');
$mech->content_contains('form', '...and get something that looks like the create form' );
$mech->content_contains('Content', 'Confirmed this is the create form');

done_testing;
