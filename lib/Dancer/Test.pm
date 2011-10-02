package Dancer::Test;
use strict;
use warnings;

use URI::Escape;

use base 'Exporter';
our @EXPORT = qw(
    dancer_response
);

use Dancer::Core::Dispatcher;

my $_dispatcher = Dancer::Core::Dispatcher->new;

sub dancer_response {
    my ($method, $path, $options) = @_;

    my $caller = caller;
    my $app = $caller->dancer_app;
    $_dispatcher->apps([ $app ]);

    my $env = {
        REQUEST_METHOD  => uc($method),
        PATH_INFO       => $path,
        HTTP_USER_AGENT => "Dancer::Test simulator v $Dancer::VERSION",
    };

    if (defined $options->{params}) {
        my @params;
        foreach my $p (keys %{$options->{params}}) {
           push @params,
             uri_escape($p).'='.uri_escape($options->{params}->{$p});
        }
        $env->{REQUEST_URI} = join('&', @params);
    }

    # TODO body
    # TODO headers
    # TODO files

    use Data::Dumper;
    warn "Env created : ".Dumper($env);
    $_dispatcher->dispatch($env);
}

1;
