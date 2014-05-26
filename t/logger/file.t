#!#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 2;
use Dancer2::Logger::File;

my $logger = Dancer2::Logger::File->new();
isa_ok( $logger, 'Dancer2::Logger::File' );
can_ok( $logger, qw<environment location log_dir file_name log_file fh> );

