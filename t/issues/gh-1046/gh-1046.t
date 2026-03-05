use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{
    ## no critic
    package App;
    use Dancer2;
    get '/' => sub {1};
}

my $test = Plack::Test->create( App->to_app );
my $res  = $test->request( GET '/' );

is(
    $res->headers->header('Server'),
    undef,
    'Server header not available',
);

done_testing;
