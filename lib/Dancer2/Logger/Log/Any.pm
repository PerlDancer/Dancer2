package Dancer2::Logger::Log::Any;
# ABSTRACT: Log::Any logger with support for structured logging

use Moo;

with 'Dancer2::Core::Role::Logger';

use Dancer2::Core::Types qw/ Str InstanceOf /;

has category => (
  is => 'ro',
  isa => Str
);
has _logger => (
    is => 'ro',
    lazy => 1,
    isa => InstanceOf[ 'Log::Any::Proxy' ],
    required => 1,
    default => sub {
        my ($self) = @_;
        my %category = $self->category ? ( category => $self->category ) : ();
        {
            local $@ = undef;
            eval { use Log::Any; 1; };
            if( $@ ) {
                warn 'Failed to use Log::Any. Have you installed it?';
            }
        }
        return Log::Any->get_logger( %category ); 
    },
);
sub log {
    my ( $self, $level, $message, $data ) = @_;
    $level = 'trace' if $level eq 'core';
    $data = \(%{ $message }, %{ $data }), $message = q{} if( ref $message );
    my $map = $self->map_chars_to_subs($level, $message, -1);
    my %info = (
        app_name => $map->{a}->(),
        package => $map->{p}->(),
        file => $map->{f}->(),
        line => $map->{l}->(),
        remote => $map->{h}->(),
        request_id => $map->{i}->(),
    );
    $data->{ $_ } = $info{ $_ } foreach (keys %info);
    $self->_logger->$level( $message ne q{} ? $message : (), $data );
}

# Create logging methods: core, debug, info, warning and error.
#
foreach my $level ( qw( core debug info warning error ) ) {
    no strict 'refs'; ## no critic (TestingAndDebugging::ProhibitNoStrict)
    no warnings 'redefine'; ## no critic (TestingAndDebugging::ProhibitNoWarnings)
    *$level = sub {
        my ( $self, @args ) = @_;
        if( ref $args[-1] eq 'HASH' ) {
            $self->_should($level) and $self->log( $level, _serialize(@args[0..($#args-1)]), $args[-1] );
        } else {
            $self->_should($level) and $self->log( $level, _serialize(@args) );
        }
    };
}

1;

__END__

=head1 DESCRIPTION

This is a logging engine that allows you to print logging messages
to any L<Log::Any::Adapter>. It supports
L<structured logging|https://metacpan.org/pod/Log::Any::Proxy#Logging-Structured-Data>.

=head USAGE

See CONFIGURATION.

You also need to configure a L<Log::Any::Adapter>. You can do this in your
F<bin/app.psgi> or in any package you read in (C<use ...>):

    use Log::Any::Adapter;
    Log::Any::Adapter->set('Stdout');

=head1 CONFIGURATION

The setting C<logger> should be set to C<Log::Any> in order to use this logging
engine in a Dancer2 application.

In your Dancer2 config:

    logger: 'Log::Any'
    engines:
        logger:
            'Log::Any':
                category: app-api

If you omit the category setting, C<Log::Any> will use the name of
this class as the category.

=head1 METHODS

=method log

Writes the log messages to any or all L<Log::Any::Adapter>s.

=method core debug info warning error

Use these in Dancer2 to log to the wanted level.

=head1 CAVEAT

This package requires L<Log::Any> installed.
It uses it lazily, loading it only at the point when it is needed.

=head1 SEE ALSO

L<Dancer2::Core::Role::Logger>

C<Log::Any>, C<Log::Any::Adapter>
