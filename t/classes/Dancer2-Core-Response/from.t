#!perl

use strict;
use warnings;
use Test::More tests => 3;

use Plack::Response;
use Dancer2::Core::Response;

sub normalize_headers {
    my $headers = shift;

    my %headers = ();
    while ( my ( $key, $val ) = splice @{$headers}, 0, 2 ) {
        $headers{$key} = $val;
    }

    return %headers;
}

can_ok( Dancer2::Core::Response::, qw<new_from_array new_from_plack> );

my %default_headers = (
    'Content-Type' => 'text/plain',
    'X-Test'       => 'Val',
);

subtest 'new_from_array' => sub {
    plan tests => 4;

    my $array    = [ 200, [%default_headers], ['Foo'] ];
    my $response = Dancer2::Core::Response->new_from_array($array);

    isa_ok( $response, 'Dancer2::Core::Response' );
    is( $response->status,  200,   'Correct status' );
    is( $response->content, 'Foo', 'Correct content' );

    # hash randomization
    my %headers = normalize_headers( $response->headers_to_array );

    is_deeply(
        \%headers,
        {
            'Server' => "Perl Dancer2 $Dancer2::VERSION",
            %default_headers,
        },
        'All headers correct',
    );
};

subtest 'new_from_plack' => sub {
    plan tests => 5;

    my $plack = Plack::Response->new();
    isa_ok( $plack, 'Plack::Response' );

    $plack->status(200);
    $plack->body('Bar');
    foreach my $header_name ( keys %default_headers ) {
        $plack->header( $header_name => $default_headers{$header_name} );
    }

    my $response = Dancer2::Core::Response->new_from_plack($plack);
    isa_ok( $response, 'Dancer2::Core::Response' );
    is( $response->status,  200,   'Correct status' );
    is( $response->content, 'Bar', 'Correct content' );

    # hash randomization
    my %headers = normalize_headers( $response->headers_to_array );

    is_deeply(
        \%headers,
        {
            'Server' => "Perl Dancer2 $Dancer2::VERSION",
            %default_headers,
        },
        'All headers correct',
    );
};

