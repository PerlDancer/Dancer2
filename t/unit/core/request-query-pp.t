use strict;
use warnings;

# WWW::Form::UrlEncoded picks its backend once, when first loaded, and
# Plack::Request imports from it at compile time, so the pure-Perl backend
# has to be forced before anything loads Plack.
BEGIN { $ENV{WWW_FORM_URLENCODED_PP} = 1 }

use Test::More;

use lib 't/lib';
use QueryStringCases qw< check_query_string_cases >;

# Without these, a module loaded too early would quietly test the XS backend
# a second time.
ok( $INC{'WWW/Form/UrlEncoded/PP.pm'}, 'the pure-Perl backend is loaded' );
ok( !$INC{'WWW/Form/UrlEncoded/XS.pm'}, 'and the XS backend is not' );

check_query_string_cases();

done_testing();
