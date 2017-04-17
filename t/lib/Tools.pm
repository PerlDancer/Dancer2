package t::lib::Tools;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(slurp);

sub slurp {
    my $f = shift;
    local $/ = undef;
    open( VAR, $f ) or die("open($f): $!");
    my $buffer = <VAR>;
    close VAR;
    return $buffer;
}

1;

