package Dancer2::Logger::Capture;
# ABSTRACT: Capture dancer logs

use Moo;
use Dancer2::Logger::Capture::Trap;

with 'Dancer2::Core::Role::Logger';

has trapper => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_trapper',
);

sub _build_trapper { Dancer2::Logger::Capture::Trap->new }

sub log {
    my ( $self, $level, $message ) = @_;

    $self->trapper->store(
        $level, $message, $self->format_message( $level => $message )
    );

    return;
}

1;

__END__

=head1 SYNOPSIS

The basics:

    set logger => "capture";

    my $trap = dancer_app->logger_engine->trapper;
    my $logs = $trap->read;

A worked-out real-world example:

    use Test::More tests => 2;
    use Dancer2;

    set logger => 'capture';

    warning "Danger!  Warning!";
    debug   "I like pie.";

    my $trap = dancer_app->logger_engine->trapper;

    is_deeply $trap->read, [
        { level => "warning", message => "Danger!  Warning!" },
        { level => "debug",   message => "I like pie.", }
    ];

    # each call to read cleans the trap
    is_deeply $trap->read, [];


=head1 DESCRIPTION

This is a logger class for L<Dancer2> which captures all logs to an object.

It's primary purpose is for testing. Here is an example of a test:

    use strict;
    use warnings;
    use Test::More;
    use Plack::Test;
    use HTTP::Request::Common;

    {
        package App;
        use Dancer2;

        set log       => 'debug';
        set logger    => 'capture';

        get '/' => sub {
            log(debug => 'this is my debug message');
            log(core  => 'this should not be logged');
            log(info  => 'this is my info message');
        };
    }

    my $app = Dancer2->psgi_app;
    is( ref $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;

        my $res = $cb->( GET '/' );

        my $trap = App->dancer_app->logger_engine->trapper;

        is_deeply $trap->read, [
            { level => 'debug', message => 'this is my debug message' },
            { level => 'info',  message => 'this is my info message' },
        ];

        is_deeply $trap->read, [];
    };

    done_testing;

=method trapper

Returns the L<Dancer2::Logger::Capture::Trap> object used to capture
and read logs.

=head1 SEE ALSO

L<Dancer2::Core::Role::Logger>, L<Dancer2::Logger::Capture::Trap>

=cut
