package poc2;

use strict;
use warnings;

use Dancer2;

BEGIN {
set plugins => {
    Polite => {
        smiley => '8-D',
    },
};
}

use Dancer2::Plugin::Polite ':app';

get '/' => sub {
    add_smileys( 'make me a sandwich.' );
};

1;




