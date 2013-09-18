package Dancer2::GetOpt;

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use File::Spec;

my %options_to_ENV  = (
	port => 'DANCER_PORT',
	environment => 'DANCER_ENVIRONMENT',
	daemon => 'DANCER_DAEMON',
	confdir => 'DANCER_CONFDIR',
);

sub arg_to_setting {
	my ($option, $value) = @_;
#	I can't really import the setting(..) func here.	
	$ENV{$options_to_ENV{$option}} = $value; #this is only way IMO it works.
}

#note we don't support the restart (auto_reload) anymore GH#391 
sub process_args {
	my $help = 0;
    GetOptions(
        'help'          => \$help,
        'port=i'        => sub { arg_to_setting(@_) },
        'daemon'        => sub { arg_to_setting(@_) },
        'environment=s' => sub { arg_to_setting(@_) },
        'confdir=s'     => sub { arg_to_setting(@_) },
    ) || show_usage_and_exit();
	
	show_usage_and_exit() if $help;
}

sub show_usage_and_exit {
	print_usage() && exit(0);	
}

sub print_usage {
	my $app = File::Spec->catfile( $FindBin::RealBin, $FindBin::RealScript );
    print <<EOF
\$ $app [options]

 Options:
   --daemon             Run in background (false)
   --port=XXXX          Port number to bind to (3000)
   --confdir=PATH       Path the config dir (appdir if not specified)
   --environment=ENV    Environment to use (development)
   --help               Display usage information

OPTIONS

--daemon

When this flag is set, the Dancer2 script will detach from the terminal and will
run in background. This is perfect for production environment but is not handy
during the development phase.

--port=XXXX

This lets you change the port number to use when running the process. By
default, the port 3000 will be used.

--confdir=PATH

By default, Dancer2 looks in the appdir for config files (config.yml and
environments files). You can change this with specifying an alternate path to
the configdir option.

Dancer2 will then look in that directory for a file config.yml and the
appropriate environement configuration file.

If not specified, confdir points to appdir.

--environment=ENV

Which environment to use. By default this value is set to development.

EOF
	
}


1;