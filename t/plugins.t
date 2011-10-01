use strict;
use warnings;
use Test::More import => ['!pass'];

use Dancer;
use Dancer::Plugin;

subtest 'reserved keywords' => sub {
    eval {
        register dance => sub {1};
    };
    like $@, qr/You can't use 'dance', this is a reserved keyword/,
        "Can't use Dancer's reserved keywords";

    {
        local @Dancer::EXPORT = (@Dancer::EXPORT, '&frobnicator');

        eval {
            register 'frobnicator' => sub {1};
        };
        like $@, qr/You can't use 'frobnicator', this is a reserved keyword/,
            "Can't use already registered keywords";

    }

    eval {
        register '1function' => sub {1};
    };
    like $@, qr/You can't use '1function', it is an invalid name/,
     "Can't use invalid names for keywords";
};

done_testing;
