use strict;
use warnings;
use Test::More tests => 5;

use Dancer2::Core::HTTP;

subtest "HTTP status" => sub {
    is( Dancer2::Core::HTTP->status( $_->{status} ) => $_->{expected},
        'status: '. ( $_->{status} || 'undef' ) )
        for { status => undef,          expected => undef },
            { status => 200,            expected => 200   },
            { status => 'Not Found',    expected => 404   },
            { status => 'bad_request',  expected => 400   },
            { status => 'i_m_a_teapot', expected => 418   },
            { status => 'error',        expected => 500   },
            { status => 911,            expected => 911   };
};


subtest "HTTP status_message" => sub {
    is( Dancer2::Core::HTTP->status_message( $_->{status} ) => $_->{expected},
        'status: '. ( $_->{status} || 'undef' ) )
        for { status => undef,   expected => undef                   },
            { status => 200,     expected => 'OK'                    },
            { status => 'error', expected => 'Internal Server Error' },
            { status => 911,     expected => undef                   };
};

is { Dancer2::Core::HTTP->status_mapping }->{"I'm a teapot"} 
    => 418, 'status_mapping';

is { Dancer2::Core::HTTP->code_mapping }->{418} 
    => "I'm a teapot", 'code_mapping';

subtest 'all_mappings' => sub {
    my %mappings = Dancer2::Core::HTTP->all_mappings;

    is $mappings{"I'm a teapot"} => 418;
    is $mappings{"i_m_a_teapot"} => 418;
    is $mappings{418} => "I'm a teapot";
};
