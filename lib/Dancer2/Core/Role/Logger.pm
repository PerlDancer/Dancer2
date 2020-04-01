package Dancer2::Core::Role::Logger;
# ABSTRACT: Role for logger engines

use Dancer2::Core::Types;

use Moo::Role;
use POSIX 'strftime';
use Encode ();
use Data::Dumper;

with 'Dancer2::Core::Role::Engine';

sub hook_aliases { +{} }
sub supported_hooks {
    qw(
      engine.logger.before
      engine.logger.after
    );
}

sub _build_type {'Logger'}

# This is the only method to implement by logger engines.
# It receives the following arguments:
# $msg_level, $msg_content, it gets called only if the configuration allows
# a message of the given level to be logged.
requires 'log';

has auto_encoding_charset => (
    is  => 'ro',
    isa => Str,
);

has app_name => (
    is      => 'ro',
    isa     => Str,
    default => sub {'-'},
);

has log_format => (
    is      => 'rw',
    isa     => Str,
    default => sub {'[%a:%P] %L @%T> %m in %f l. %l'},
);

my $_levels = {

    # levels < 0 are for core only
    core => -10,

    # levels > 0 are for end-users only
    debug   => 1,
    info    => 2,
    warn    => 3,
    warning => 3,
    error   => 4,
};

has log_level => (
    is  => 'rw',
    isa => Enum[keys %{$_levels}],
    default => sub {'debug'},
);

sub _should {
    my ( $self, $msg_level ) = @_;
    my $conf_level = $self->log_level;
    return $_levels->{$conf_level} <= $_levels->{$msg_level};
}

sub format_message {
    my ( $self, $level, $message ) = @_;
    chomp $message;

    $message = Encode::encode( $self->auto_encoding_charset, $message )
      if $self->auto_encoding_charset;

    my @stack = caller(8);
    my $request = $self->request;
    my $config = $self->config;

    my $block_handler = sub {
        my ( $block, $type ) = @_;
        if ( $type eq 't' ) {
            return POSIX::strftime( $block, localtime(time) );
        }
        elsif ( $type eq 'h' ) {
            return ( $request && $request->header($block) ) || '-';
        }
        else {
            Carp::carp("{$block}$type not supported");
            return "-";
        }
    };

    my $chars_mapping = {
        a => sub { $self->app_name },
        t => sub { POSIX::strftime( "%d/%b/%Y %H:%M:%S", localtime(time) ) },
        T => sub { POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime(time) ) },
        u => sub { POSIX::strftime( "%d/%b/%Y %H:%M:%S", gmtime(time) ) },
        U => sub { POSIX::strftime( "%Y-%m-%d %H:%M:%S", gmtime(time) ) },
        P => sub {$$},
        L => sub {$level},
        m => sub {$message},
        f => sub { $stack[1] || '-' },
        l => sub { $stack[2] || '-' },
        h => sub {
            ( $request && ( $request->remote_host || $request->address ) ) || '-'
        },
        i => sub { ( $request && $request->id ) || '-' },
    };

    my $char_mapping = sub {
        my $char = shift;

        my $cb = $chars_mapping->{$char};
        if ( !$cb ) {
            Carp::carp "%$char not supported.";
            return "-";
        }
        $cb->($char);
    };

    my $fmt = $self->log_format;

    $fmt =~ s/
        (?:
            \%\{(.+?)\}([a-z])|
            \%([a-zA-Z])
        )
    / $1 ? $block_handler->($1, $2) : $char_mapping->($3) /egx;

    return $fmt . "\n";
}

sub _serialize {
    my @vars = @_;

    return join q{}, map +(
        ref $_
          ? Data::Dumper->new( [$_] )->Terse(1)->Purity(1)->Indent(0)
          ->Sortkeys(1)->Dump()
          : ( defined($_) ? $_ : 'undef' )
    ), @vars;
}

around 'log' => sub {
    my ($orig, $self, @args) = @_;

    $self->execute_hook( 'engine.logger.before', $self, @args );
    $self->$orig( @args );
    $self->execute_hook( 'engine.logger.after', $self, @args );
};

sub core {
    my ( $self, @args ) = @_;
    $self->_should('core') and $self->log( 'core', _serialize(@args) );
}

sub debug {
    my ( $self, @args ) = @_;
    $self->_should('debug') and $self->log( 'debug', _serialize(@args) );
}

sub info {
    my ( $self, @args ) = @_;
    $self->_should('info') and $self->log( 'info', _serialize(@args) );
}

sub warning {
    my ( $self, @args ) = @_;
    $self->_should('warning') and $self->log( 'warning', _serialize(@args) );
}

sub error {
    my ( $self, @args ) = @_;
    $self->_should('error') and $self->log( 'error', _serialize(@args) );
}

1;

__END__

=head1 DESCRIPTION

Any class that consumes this role will be able to implement to write log messages.

In order to implement this role, the consumer B<must> implement the C<log>
method. This method will receives as argument the C<level> and the C<message>.

=head1 CONFIGURATION

The B<logger> configuration variable tells Dancer2 which engine to use.

You can change it either in your config.yml file:

    # logging to console
    logger: "console"

The log format can also be configured,
please see L<Dancer2::Core::Role::Logger/"log_format"> for details.

=head1 METHODS

=method core

Log messages as B<core>.

=method debug

Log messages as B<debug>.

=method info

Log messages as B<info>.

=method warning

Log messages as B<warning>.

=method error

Log messages as B<error>.

=method format_message

Provides a common message formatting.

=attr auto_encoding_charset

Charset to use when writing a message.

=attr app_name

Name of the application. Can be used in the message.

=attr log_format

This is a format string (or a preset name) to specify the log format.

The possible values are:

=over 4

=item %h

host emitting the request

=item %t

date (local timezone, formatted like %d/%b/%Y %H:%M:%S)

=item %T

date (local timezone, formatted like %Y-%m-%d %H:%M:%S)

=item %u

date (UTC timezone, formatted like %d/%b/%Y %H:%M:%S)

=item %U

date (UTC timezone, formatted like %Y-%m-%d %H:%M:%S)

=item %P

PID

=item %L

log level

=item %D

timer

=item %m

message

=item %f

file name that emit the message

=item %l

line from the file

=item %i

request ID

=item %{$fmt}t

timer formatted with a valid time format

=item %{header}h

header value

=back

=attr log_level

Level to use by default.
