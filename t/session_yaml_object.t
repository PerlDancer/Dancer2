use strict;
use warnings;

use Dancer2::Session::YAML ();
use File::Temp ();
use IO::File ();

use Test::More;

my $tempdir = File::Temp->newdir;

my $engine = Dancer2::Session::YAML->new( session_dir => $tempdir->dirname );
my $session_id = do {
    my $session = $engine->create;
    isa_ok $session, 'Dancer2::Core::Session', 'Create a session';
    ok $session->write( uvw => 7 ), 'Store a session value';
    ok $session->write( xyz => $tempdir ), 'Store a session object';
    ok $engine->flush( session => $session ), 'Flush the session store';
    $session->id;
};
{
    my $session = $engine->retrieve( id => $session_id );
    isa_ok $session, 'Dancer2::Core::Session', 'Retrieve the session';
    is $session->read('uvw'), 7, 'The session has stored the value';
    isa_ok $session->read('xyz'),'File::Temp::Dir', 'The session has stored the object';
}

done_testing();
