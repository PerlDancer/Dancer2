#!perl

use strict;
use warnings;

use Test::More tests => 25;
use Plack::Test;
use HTTP::Request::Common;

{ package App1; use Dancer2; get '/1' => sub {1}; }
{ package App2; use Dancer2; get '/2' => sub {2}; }
{ package App3; use Dancer2; get '/3' => sub {3}; }

sub is_available {
    my ( $cb, @apps ) = @_;
    foreach my $app (@apps) {
        is( $cb->( GET "/$app" )->content, $app, "App$app available" );
    }
}

sub isnt_available {
    my ( $cb, @apps ) = @_;
    foreach my $app (@apps) {
        is(
            $cb->( GET "/$app" )->code,
            404,
            "App$app is not available",
        );
    }
}

note 'All Apps'; {
    my $app = Dancer2->psgi_app;
    isa_ok( $app, 'CODE', 'Got PSGI app' );
    test_psgi $app, sub {
        my $cb = shift;
        is_available( $cb, 1, 2, 3 );
    };
}

note 'Specific Apps by parameters'; {
    my @apps = @{ Dancer2->runner->apps }[ 0, 2 ];
    is( scalar @apps, 2, 'Took two apps from the Runner' );
    my $app = Dancer2->psgi_app(\@apps);
    isa_ok( $app, 'CODE', 'Got PSGI app' );
    test_psgi $app, sub {
        my $cb = shift;
        is_available( $cb, 1, 3 );
        isnt_available( $cb, 2 );
    };
}

note 'Specific Apps via App objects'; {
    my $app = App2->psgi_app;
    isa_ok( $app, 'CODE', 'Got PSGI app' );
    test_psgi $app, sub {
        my $cb = shift;
        is_available( $cb, 2 );
        isnt_available( $cb, 1, 3 );
    };
};

note 'Specific apps by App names'; {
    my $app = Dancer2->psgi_app( [ 'App1', 'App3' ] );
    isa_ok( $app, 'CODE', 'Got PSGI app' );
    test_psgi $app, sub {
        my $cb = shift;
        isnt_available( $cb, 2 );
        is_available( $cb, 1, 3 );
    };
}

note 'Specific apps by App names with regular expression, v1'; {
    my $app = Dancer2->psgi_app( [ qr/^App1$/, qr/^App3$/ ] );
    isa_ok( $app, 'CODE', 'Got PSGI app' );
    test_psgi $app, sub {
        my $cb = shift;
        isnt_available( $cb, 2 );
        is_available( $cb, 1, 3 );
    };
}

note 'Specific apps by App names with regular expression, v2'; {
    my $app = Dancer2->psgi_app( [ qr/^App(2|3)$/ ] );
    isa_ok( $app, 'CODE', 'Got PSGI app' );
    test_psgi $app, sub {
        my $cb = shift;
        isnt_available( $cb, 1 );
        is_available( $cb, 2, 3 );
    };
}

