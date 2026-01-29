use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

use Dancer2;
use Dancer2::Core::Response;

sub _headers_have_server {
    my ($headers) = @_;
    return scalar grep { defined $_ && $_ eq 'Server' } @$headers;
}

subtest 'Response->to_psgi does not add Server header' => sub {
    my $res = Dancer2::Core::Response->new( content => 'ok' );
    my $psgi = $res->to_psgi;
    ok !$psgi->[1] || !_headers_have_server( $psgi->[1] ),
        'Server header not present in PSGI response headers';
};

subtest 'to_app does not add Server header' => sub {
    {
        package App;
        use Dancer2;
        get '/' => sub { 'ok' };
    }

    my $test = Plack::Test->create( App->to_app );
    my $res  = $test->request( GET '/' );
    is $res->headers->header('Server'), undef, 'Server header not available';
};

done_testing;
