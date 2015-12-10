use strict;
use Test::More tests => 1;

{
    package App::NoWarnings; ## no critic
    no warnings 'misc'; # masks earlier declaration
    use Dancer2 ':nopragmas';

    local $@ = undef;
    my $got_warning;

    local $SIG{'__WARN__'} = sub {
        $got_warning++;
    };

    eval 'my $var; my $var;'; ## no critic
    ::is( $got_warning, undef, 'warnings pragma not activated' );
}
