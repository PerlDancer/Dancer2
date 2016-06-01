package poc2;

use strict;
use warnings;

use Dancer2;
set logger => 'Capture';

BEGIN {
set plugins => {
    Polite => {
        smiley => '8-D',
    },
};
}

use PoC::Plugin::Polite ':app';

hook 'smileys' => sub {
    send_error "Not in sudoers file. This incident will be reported";
};

get '/' => sub {
    add_smileys( 'make me a sandwich.' );
};

get '/sudo' => sub {
    hooked_smileys( 'make me a sandwich.' );
};

1;

