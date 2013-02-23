use strict;
use warnings;

use Test::More tests => 2;

{
    package MyApp;

    use Dancer2;

    set serializer => 'JSON';

    put '/from_params' => sub {
        my %p = params();
        return join " : ", map { $_ => $p{$_} } sort keys %p;
    };

    put '/from_data' => sub {
        my $p = request->data;
        return join " : ", map { $_ => $p->{$_} } sort keys %$p;
    };
}

use Dancer2::Test apps => [ 'MyApp' ];

is dancer_response( Dancer2::Core::Request->new(
    method => 'PUT',
    path => "/from_$_",
    content_type => 'application/json',
    body => '{ "foo": 1, "bar": 2 }',
))->content => 'bar : 2 : foo : 1', "using $_"
    for qw/ params data /;
