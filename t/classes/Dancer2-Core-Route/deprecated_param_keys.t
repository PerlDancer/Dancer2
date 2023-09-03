use strict;
use warnings;
use Test::More;
use Test::Fatal;
BEGIN { use_ok('Dancer2::Core::Route') }

like( exception {
        Dancer2::Core::Route->new(
            regexp => '/:splat',
            code   => sub {1},
            method => 'get',
        );
    },
    qr{^Named placeholder 'splat' is deprecated},
    'Find deprecation of :splat'
);

like( exception {
        Dancer2::Core::Route->new(
            regexp => '/:captures',
            code   => sub {1},
            method => 'get',
        );
    },
    qr{^Named placeholder 'captures' is deprecated},
    'Find deprecation of :captures',
);

done_testing;
