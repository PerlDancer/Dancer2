use strict;
use warnings;
use Plack::Test;
use HTTP::Request::Common;
use Test::More tests => 2;

{
    package App1;
    use Dancer2;
    get '/' => sub {'App1'};

    my $app = to_app;
    ::test_psgi $app, sub {
        my $cb = shift;
        ::is( $cb->( ::GET '/' )->content, 'App1', 'Got first App' );
    };
}

{
    package App2;
    use Dancer2;
    get '/' => sub {'App2'};

    my $app = to_app;
    ::test_psgi $app, sub {
        my $cb = shift;
        ::is( $cb->( ::GET '/' )->content, 'App2', 'Got second App' );
    };
}


