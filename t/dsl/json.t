use strict;
use warnings;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;
    get '/' => sub {
        my $app = app;

        my %test = (foo => 'bar');

        ::is( encode_json(\%test), '{"foo":"bar"}', 'encode_json works' );
        ::is_deeply( decode_json(encode_json(\%test)), \%test, 'decode_json works' );
    };
}

Plack::Test->create( App->to_app )->request( GET '/' );
