package Dancer2::Plugin2;

use strict;
use warnings;

use Moo;

extends 'Exporter::Tiny';

sub _exporter_expand_tag {
    my( $class, $name, $args, $global ) = @_;

    return unless $name eq 'app';

    my( $caller ) = caller(1);

    die "plugin called with ':app' in a class without app()\n"
        unless $caller->can('app');

    ( my $short = $class ) =~ s/Dancer2::Plugin:://;

    my $app = eval "${caller}::app()";

    my $plugin = $app->with_plugins( $short );
    $global->{plugin} = $plugin;

    return unless $class->can('keywords');

    map { [ $_ =>  {plugin => $plugin}  ] } $class->keywords;
}

sub _exporter_expand_sub {
    my( $plugin, $name, $args, $global ) = @_;

    return $name => sub(@) { $args->{plugin}->$name(@_) };
}


has app => (
#    isa => Object['Dancer2::Core::App'],
    is => 'ro',
    required => 1,
);

has config => (
    is => 'ro',
    lazy => 1,
    default => sub { 
        my $self = shift;
        my $config = $self->app->config;
        my $package = ref $self; # TODO
        $package =~ s/Dancer2::Plugin:://;
        $config->{plugins}{$package}
    },
);

1;
