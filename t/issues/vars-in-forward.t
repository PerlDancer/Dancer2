use strict;
use warnings;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;
    get '/' => sub {
        var foo => 'bar';
        forward '/next';
    };

    get '/next' => sub {
        vars->{'foo'};
    };
}

my $test = Plack::Test->create( App->to_app );
my $res  = $test->request( GET '/' );

ok( $res->is_success, 'Successful response' );
is( $res->content, 'bar', 'Correct response' );
