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

        ::is( to_yaml(\%test), "---\nfoo: bar\n", 'to_yaml works' );
        ::is_deeply( from_yaml(to_yaml(\%test)), \%test, 'from_yaml works' );
    };
}

Plack::Test->create( App->to_app )->request( GET '/' );
