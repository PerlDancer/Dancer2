#!/usr/bin/env perl

use strict;

BEGIN {
    $|  = 1;
    $^W = 1;
}
use vars qw{$VAR1 $VAR2};
use Test::More;
use File::Spec::Functions ':ALL';
use Dancer2::Template::Implementation::ForkedTiny ();
use FindBin qw($Bin);

my $SAMPLES = catdir( $Bin, 'samples' );
unless ( -d $SAMPLES ) {
    die("Failed to find samples directory");
}

opendir( DIR, $SAMPLES ) or die("opendir($SAMPLES): $!");
my @TEMPLATES = sort grep {/\.tt$/} readdir(DIR);
closedir(DIR) or die("closedir($SAMPLES): $!");

plan( tests => scalar(@TEMPLATES) * 6 );

# Test the test classes
#SCOPE: {
#    my $false = bless { }, 'False';
#    my $string = $false . '';
#    is( $string, 'Hello', 'False objects return ok as a string' );
#    is( !!$false, '', 'False objects returns false during bool' );
#}


######################################################################
# Main Tests

foreach my $template (@TEMPLATES) {
    $template =~ s/\.tt$//;
    my $file     = catfile( $SAMPLES, $template );
    my $tt_file  = "$file.tt";
    my $var_file = "$file.var";
    my $txt_file = "$file.txt";
    ok( -f $tt_file,  "$template: Found $tt_file" );
    ok( -f $txt_file, "$template: Found $txt_file" );
    ok( -f $var_file, "$template: Found $var_file" );

    # Load the resources
    my $tt  = slurp($tt_file);
    my $var = slurp($var_file);
    my $txt = slurp($txt_file);
    eval $var;
    die $@ if $@;
    is( ref($VAR1), 'HASH', "$template: Loaded stash from file" );

    # Create the processor normally
    my %params = ( INCLUDE_PATH => $SAMPLES, );
    %params = ( %params, %$VAR2 ) if $VAR2;
    my $template = Dancer2::Template::Implementation::ForkedTiny->new(%params);
    isa_ok( $template, 'Dancer2::Template::Implementation::ForkedTiny' );

    # Execute the template
    $template->process( \$tt, $VAR1, \my $out );
    is( $out, $txt, "$template: Output matches expected" );
}

sub slurp {
    my $f = shift;
    local $/ = undef;
    open( VAR, $f ) or die("open($f): $!");
    my $buffer = <VAR>;
    close VAR;
    return $buffer;
}


######################################################################
# Support Classes for object tests

SCOPE: {

    package UpperCase;

    sub foo {
        uc $_[0]->{foo};
    }

    1;
}

SCOPE: {

    package False;

    use overload 'bool' => sub {0};
    use overload '""'   => sub {'Hello'};

    1;
}

SCOPE: {

    package Private;

    sub public   {'foo'}
    sub _private {'foo'}

    1;
}
