#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 36;

{
    package Handler;
    use Moo;
    with 'Dancer2::Core::Role::StandardResponses';
}

{
    package App;
    use Moo;
    has response => ( is => 'ro', default => sub { Response->new } );
}

{
    package Response;
    use Moo;
    sub status { shift->{'status'}->(@_) }
    sub header { shift->{'header'}->(@_) }
}

note 'Checking our fake app'; {
    my $app = App->new;
    isa_ok( $app, 'App'      );
    can_ok( $app, 'response' );
    isa_ok( $app->response, 'Response' );
}

note 'Checking our fake response'; {
    my $response = Response->new(
        status => sub {
            my ( $self, $input ) = @_;
            ::isa_ok( $self, 'Response' );
            ::is( $input, 'calling status', 'status called' );
            return 'foo';
        },

        header => sub {
            my ( $self, $input ) = @_;
            ::isa_ok( $self, 'Response' );
            ::is( $input, 'calling header', 'header called' );
            return qw<bar baz>;
        },
    );

    isa_ok( $response, 'Response' );

    is_deeply(
        [ $response->status('calling status') ],
        [ 'foo' ],
        'status() works',
    );

    is_deeply(
        [ $response->header('calling header') ],
        [ qw<bar baz> ],
        'header() works',
    );
}

my $handler = Handler->new;
isa_ok( $handler, 'Handler' );
can_ok( $handler, qw<response response_400 response_403 response_404> );

note '->response'; {
    # set up status and header
    my $app = App->new(
        response => Response->new(
            status => sub {
                my ( $self, $code ) = @_;
                ::isa_ok( $self, 'Response' );
                ::is( $code, '400', 'Correct status code' );
            },

            header => sub {
                my ( $self, $hdr_name, $hdr_content ) = @_;
                ::isa_ok( $self, 'Response' );
                ::is( $hdr_name, 'Content-Type', 'Correct header name' );
                ::is( $hdr_content, 'text/plain', 'Correct header value' );
            },
        )
    );

    is(
        $handler->response( $app, 400, 'Some Message' ),
        'Some Message',
        'Correct response created',
    );
}

note '->response_400'; {
    # set up status and header
    my $app = App->new(
        response => Response->new(
            status => sub {
                my ( $self, $code ) = @_;
                ::isa_ok( $self, 'Response' );
                ::is( $code, '400', 'Correct status code' );
            },

            header => sub {
                my ( $self, $hdr_name, $hdr_content ) = @_;
                ::isa_ok( $self, 'Response' );
                ::is( $hdr_name, 'Content-Type', 'Correct header name' );
                ::is( $hdr_content, 'text/plain', 'Correct header value' );
            },
        )
    );

    is(
        $handler->response_400($app),
        'Bad Request',
        'Correct response 400 created',
    );
}

note '->response_403'; {
    # set up status and header
    my $app = App->new(
        response => Response->new(
            status => sub {
                my ( $self, $code ) = @_;
                ::isa_ok( $self, 'Response' );
                ::is( $code, '403', 'Correct status code' );
            },

            header => sub {
                my ( $self, $hdr_name, $hdr_content ) = @_;
                ::isa_ok( $self, 'Response' );
                ::is( $hdr_name, 'Content-Type', 'Correct header name' );
                ::is( $hdr_content, 'text/plain', 'Correct header value' );
            },
        )
    );

    is(
        $handler->response_403($app),
        'Unauthorized',
        'Correct response 403 created',
    );
}

note '->response_404'; {
    # set up status and header
    my $app = App->new(
        response => Response->new(
            status => sub {
                my ( $self, $code ) = @_;
                ::isa_ok( $self, 'Response' );
                ::is( $code, '404', 'Correct status code' );
            },

            header => sub {
                my ( $self, $hdr_name, $hdr_content ) = @_;
                ::isa_ok( $self, 'Response' );
                ::is( $hdr_name, 'Content-Type', 'Correct header name' );
                ::is( $hdr_content, 'text/plain', 'Correct header value' );
            },
        )
    );

    is(
        $handler->response_404($app),
        'Not Found',
        'Correct response 404 created',
    );
}
