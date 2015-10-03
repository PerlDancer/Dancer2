use strict;
use warnings;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;

BEGIN { $ENV{'DANCER_NO_SERVER_TOKENS'} = 'foo' }

{
    package App;
    use Dancer2;
    get '/' => sub { config->{'no_server_tokens'} };
}

my $test = Plack::Test->create( App->to_app );
my $res  = $test->request( GET '/' );

ok( $res->is_success, 'Successful' );
is( $res->content, 'foo', 'Correct server tokens configuration' );

