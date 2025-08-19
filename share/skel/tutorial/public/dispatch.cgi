#!/usr/bin/env perl
BEGIN { $ENV{DANCER_APPHANDLER} = 'PSGI';}
use Dancer2;
use FindBin '$RealBin';
use Plack::Runner;

# For some reason Apache SetEnv directives don't propagate
# correctly to the dispatchers, so forcing PSGI and env here
# is safer.
set apphandler => 'PSGI';
set environment => 'production';

my $psgi = path($RealBin, '..', 'bin', 'app.psgi');
die "Unable to read startup script: $psgi" unless -r $psgi;

Plack::Runner->run($psgi);
