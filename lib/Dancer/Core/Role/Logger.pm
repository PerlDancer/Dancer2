# ABSTRACT: TODO

package Dancer::Core::Role::Logger;
use Dancer::Core::Types;

use POSIX qw/strftime/;
use Moo::Role;
with 'Dancer::Core::Role::Engine';

sub supported_hooks {
    qw(
    engine.logger.before
    engine.logger.after
    )
}

sub _build_type {'Logger'}

# This is the only method to implement by logger engines.
# It receives the following arguments:
# $msg_level, $msg_content, it gets called only if the configuration allows
# a message of the given level to be logged.
requires 'log';

has auto_encoding_charset => (
    is => 'ro',
    isa => Str,
);

has app_name => (
    is => 'ro',
    isa => Str,
);


has log_format => (
    is => 'rw',
    isa => Str,
    default => sub { '[%a:%P] %L @%T> %m in %f l. %l' },
);

my $_levels = {
    # levels < 0 are for core only
    core => -10,

    # levels > 0 are for end-users only
    debug   => 1,
    warn    => 2,
    warning => 2,
    error   => 3,
};

has log_level => (
    is => 'rw',
    isa => sub { grep { /$_[0]/} keys %{$_levels} },
    default => sub { 'debug' },
);

sub _should {
    my ($self, $msg_level) = @_;
    my $conf_level = $self->log_level;
    return $_levels->{$conf_level} <= $_levels->{$msg_level};
}

sub format_message {
    my ($self, $level, $message) = @_;
    chomp $message;

    $level = sprintf('%5s', $level);
    $message = Encode::encode($self->auto_encoding_charset, $message)
        if $self->auto_encoding_charset;

    my @stack = caller(2);

    my $block_handler = sub {
        my ( $block, $type ) = @_;
        if ( $type eq 't' ) {
            return "[" . strftime( $block, localtime(time) ) . "]";
        }
        else {
            Carp::carp("{$block}$type not supported");
            return "-";
        }
    };

    my $chars_mapping = {
        a => sub { $self->app_name },
        t => sub { Encode::decode(setting('charset'),
                                  POSIX::strftime( "%d/%b/%Y %H:%M:%S", localtime(time) )) },
        T => sub { POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime(time)  ) },
        P => sub { $$ },
        L => sub { $level },
        m => sub { $message },
        f => sub { $stack[1] || '-' },
        l => sub { $stack[2] || '-' },
    };

    my $char_mapping = sub {
        my $char = shift;

        my $cb = $chars_mapping->{$char};
        if (! $cb) {
            Carp::carp "\%$char not supported.";
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

    return $fmt."\n";
}

sub core    { $_[0]->_should('core')    and $_[0]->log('core',    $_[1]) }
sub debug   { $_[0]->_should('debug')   and $_[0]->log('debug',   $_[1]) }
sub warning { $_[0]->_should('warning') and $_[0]->log('warning', $_[1]) }
sub error   { $_[0]->_should('error')   and $_[0]->log('error',   $_[1]) }

1;
