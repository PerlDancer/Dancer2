package Dancer2::CLI;
# ABSTRACT: Dancer2 cli application

use strict;
use warnings;

BEGIN {
    eval {
        require App::Cmd::Setup;
        1; 
    } or do {
        warn "ERROR: You need to install App::Cmd first to use this tool";
        exit;
    }
}

use App::Cmd::Setup -app;

1;
