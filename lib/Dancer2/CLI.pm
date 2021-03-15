package Dancer2::CLI;
# ABSTRACT: Dancer2 cli application

use strict;
use warnings;

BEGIN {
    eval {
        require App::Cmd::Setup;
        1; 
    } or do {
        warn <<INSTALLAPPCMD;
ERROR: You need to install App::Cmd first to use this tool.

You can do so using your preferred module installation method, for instance;

  # using cpanminus
  cpanm App::Cmd
  # or using CPAN.pm
  cpan App::Cmd
  
For more detailed instructions, see http://www.cpan.org/modules/INSTALL.html

Without App::Cmd, the `dancer2` app minting tool cannot be used, but Dancer2
can still be used for existing apps.
INSTALLAPPCMD
        exit;
    }
}

use App::Cmd::Setup -app;

1;
