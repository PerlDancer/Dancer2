use strict;
use warnings;
use Test::More tests => 11;

use Dancer2::Core::HTTP;

note "HTTP status"; {
    my @tests = (
        { status => undef,          expected => undef },
        { status => 200,            expected => 200   },
        { status => 'Not Found',    expected => 404   },
        { status => 'bad_request',  expected => 400   },
        { status => 'i_m_a_teapot', expected => 418   },
        { status => 'error',        expected => 500   },
        { status => 911,            expected => 911   },
    );

    for my $test (@tests) {
        my $status_text = defined $test->{status}
            ? $test->{status} : 'undef';
        is( Dancer2::Core::HTTP->status( $test->{status} ),
            $test->{expected},
            "HTTP status looks good for $status_text" );
    }
}


note "HTTP status_message"; {
    my @tests = (
        { status => undef,   expected => undef                   },
        { status => 200,     expected => 'OK'                    },
        { status => 'error', expected => 'Internal Server Error' },
        { status => 911,     expected => undef                   },
    );

    for my $test (@tests) {
        my $status_text = defined $test->{status}
            ? $test->{status} : 'undef';
        is( Dancer2::Core::HTTP->status_message( $test->{status} ),
            $test->{expected},
            "HTTP status message looks good for $status_text" );
    }
}
