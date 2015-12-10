use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common qw/GET/;
use Dancer2;

{
    package Test::App;
    use Dancer2;

    use Data::Dumper;
    set behind_proxy => 1;
    set views        => 't/views';

    # The 'die' was causing the Runners' internal_request
    # object to not get cleaned up when returning from dispatch.
    hook before => sub { die "Nope, Nope, Nope" };

    get '/' => sub {
        send_error "Yes yes YES!";
    };
}

my $test = Plack::Test->create(Dancer2->psgi_app);

my $res = $test->request(GET '/');
is( Dancer2->runner->{'internal_request'}, undef,
    "Runner internal request cleaned up" );

done_testing;

