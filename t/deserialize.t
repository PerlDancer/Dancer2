use strict;
use warnings;

use Test::More tests => 4;

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

    post '/to_json' => sub {
        my %p = params();
        return to_json(\%p);
    };
}

use utf8;
use JSON;
use Encode;
use Dancer2::Test apps => [ 'MyApp' ];

is dancer_response( Dancer2::Core::Request->new(
    method => 'PUT',
    path => "/from_$_",
    content_type => 'application/json',
    body => '{ "foo": 1, "bar": 2 }',
))->content => 'bar : 2 : foo : 1', "using $_"
    for qw/ params data /;

## Tests decoding/encoding happens sanely
my $utf8 = '∮ E⋅da = Q,  n → ∞, ∑ f(i) = ∏ g(i)';
my $r = dancer_response( Dancer2::Core::Request->new(
    method          => 'PUT',
    path            => '/from_params',
    content_type    => 'application/json',
    body            => JSON::to_json({string => $utf8}, {utf8 => 1}),
));
my $content = Encode::decode('UTF-8', $r->content);
is($content, "string : $utf8", 'utf-8 string returns the same');

## Tests integers remain integers (decoding shouldn't happen on individual
## params on application/json data
$r = dancer_response( Dancer2::Core::Request->new(
    method          => 'POST',
    path            => '/to_json',
    content_type    => 'application/json',
    body            => JSON::to_json({ a => 4 }),
));

is($r->content, '{"a":4}', 'Integer remains integer');
