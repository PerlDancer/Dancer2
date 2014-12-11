package Dancer2::Core::Time;
# ABSTRACT: class to handle common helpers for time manipulations

use Moo;

has seconds => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_seconds',
);

sub _build_seconds {
    my ($self) = @_;
    my $seconds = $self->expression;

    return $seconds
        if $seconds =~ /^\d+$/;

    return $self->_parse_duration($seconds)
}

has epoch => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_epoch',
);

sub _build_epoch {
    my ($self) = @_;
    return $self->seconds if $self->seconds !~ /^[\-\+]?\d+$/;
    $self->seconds + time;
}

has gmt_string => (
    is      => 'ro',
    builder => '_build_gmt_string',
    lazy    => 1,
);

sub _build_gmt_string {
    my ($self) = @_;
    my $epoch = $self->epoch;
    return $epoch if $epoch !~ /^\d+$/;

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) = gmtime($epoch);
    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @days   = qw(Sun Mon Tue Wed Thu Fri Sat);

    return sprintf "%s, %02d-%s-%d %02d:%02d:%02d GMT",
      $days[$wday],
      $mday,
      $months[$mon],
      ( $year + 1900 ),
      $hour, $min, $sec;
}

has expression => (
    is       => 'ro',
    required => 1,
);

sub BUILDARGS {
    my ($class, %args) = @_;

    $args{epoch} = $args{expression}
        if $args{expression} =~ /^\d+$/;

    return \%args;
}

# private

# This map is taken from Cache and Cache::Cache
# map of expiration formats to their respective time in seconds
#<<< no perl tidy
my %Units = ( map(($_,             1), qw(s second seconds sec secs)),
              map(($_,            60), qw(m minute minutes min mins)),
              map(($_,         60*60), qw(h hr hour hours)),
              map(($_,      60*60*24), qw(d day days)),
              map(($_,    60*60*24*7), qw(w week weeks)),
              map(($_,   60*60*24*30), qw(M month months)),
              map(($_,  60*60*24*365), qw(y year years)) );
#>>>

# This code is taken from Time::Duration::Parse, except if it isn't
# understood it just passes it through and it adds the current time.
sub _parse_duration {
    my ( $self, $timespec ) = @_;
    my $orig_timespec = $timespec;

    # Treat a plain number as a number of seconds (and parse it later)
    if ( $timespec =~ /^\s*([-+]?\d+(?:[.,]\d+)?)\s*$/ ) {
        $timespec = "$1s";
    }

    # Convert hh:mm(:ss)? to something we understand
    $timespec =~ s/\b(\d+):(\d\d):(\d\d)\b/$1h $2m $3s/g;
    $timespec =~ s/\b(\d+):(\d\d)\b/$1h $2m/g;

    my $duration = 0;
    while ( $timespec
        =~ s/^\s*([-+]?\d+(?:[.,]\d+)?)\s*([a-zA-Z]+)(?:\s*(?:,|and)\s*)*//i )
    {
        my ( $amount, $unit ) = ( $1, $2 );
        $unit = lc($unit) unless length($unit) == 1;

        if ( my $value = $Units{$unit} ) {
            $amount =~ s/,/./;
            $duration += $amount * $value;
        }
        else {
            return $orig_timespec;
        }
    }

    if ( $timespec =~ /\S/ ) {
        return $orig_timespec;
    }

    return sprintf "%.0f", $duration;
}

1;

__END__

=head1 DESCRIPTION

For consistency, whenever something needs to work with time, it
needs to be expressed in seconds, with a timestamp. Although it's very
convenient for the machine and calculations, it's not very handy for a
human-being, for instance in a configuration file.

This class provides everything needed to translate any human-understandable
expression into a number of seconds.

=head1 SYNOPSIS

    my $time = Dancer2::Core::Time->new( expression => "1h" );
    $time->seconds; # return 3600

=attr seconds

Number of seconds represented by the object. Defaults to 0.

=attr epoch

The current epoch to handle. Defaults to seconds + time.

=attr gmt_string

Convert the current value in epoch as a GMT string.

=attr expression

Required. A human readable expression representing the number of seconds to provide.

The format supported is a number followed by an expression. It currently
understands:

    s second seconds sec secs
    m minute minutes min mins
    h hr hour hours
    d day days
    w week weeks
    M month months
    y year years

Months and years are currently fixed at 30 and 365 days.  This may change.
Anything else is used verbatim as the expression of a number of seconds.

Example:

    2 hours, 3 days, 3d, 1 week, 3600, etc...

=cut
