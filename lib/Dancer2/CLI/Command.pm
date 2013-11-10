# ABSTRACT: Dancer2 CLI base class for commands
package Dancer2::CLI::Command;

use strict;
use warnings;

use LWP::UserAgent;
use App::Cmd::Setup -command;

# apart of introducing global option 'no-check'
# this cde will also make easy to add any global options in future

sub opt_spec {
    my ($class, $app) = @_;
    return (
        $class->options($app),
        [ 'no-check|x', "don't check for the latest version of Dancer2 (checking version implies internet connection)" ],
    )
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    $self->validate($opt, $args);
    $self->_version_check() unless $opt->{'no_check'};
}

sub options {}
sub validate {}

sub version {
    require Dancer2;
    return $Dancer2::VERSION;
}

# version check routines
sub _version_check {
    my $self = shift;
    my $version = $self->version();
    return if $version =~  m/_/;
    
    my $latest_version = 0;
    my $resp = _send_http_request('http://search.cpan.org/api/module/Dancer2');

    if ($resp) {
        if ( $resp =~ /"version" (?:\s+)? \: (?:\s+)? "(\d\.\d+)"/x ) {
            $latest_version = $1;
        } else {
            die "Can't understand search.cpan.org's reply.\n";
        }
    }

    if ($latest_version > $version) {
        print qq|
The latest stable Dancer2 release is $latest_version, you are currently using $version.
Please check http://search.cpan.org/dist/Dancer2/ for updates.

|;
    }
}

sub _send_http_request {
    my $url = shift;

    my $ua = LWP::UserAgent->new;
    $ua->timeout(5);
    $ua->env_proxy();

    my $response = $ua->get($url);
    return $response->is_success ? $response->content : undef;
}

1;
