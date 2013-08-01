# ABSTRACT: Dancer2's route handler

package Dancer2::Core::Route;

use strict;
use warnings;

use Moo;
use Dancer2::Core::Types;
use Carp 'croak';

=attr method

The HTTP method of the route (lowercase). Required.

=cut

has method => (
    is       => 'ro',
    isa      => Dancer2Method,
    required => 1,
);

=attr code

The code reference to execute when the route is ran. Required.

=cut

has code => (
    is       => 'ro',
    required => 1,
    isa      => CodeRef,
);

=attr regexp

The regular expression that defines the path of the route.
Required. Coerce from Dancer2's route I<patterns>.

=cut

has regexp => (
    is       => 'ro',
    required => 1,
);

has spec_route => ( is => 'ro' );

=attr prefix

The prefix to prepend to the C<regexp>. Optional.

=cut

has prefix => (
    is        => 'ro',
    isa       => Maybe [Dancer2Prefix],
    predicate => 1,
);

=attr options

A HashRef of conditions on which the matching will depend. Optional.

=cut

has options => (
    is        => 'ro',
    isa       => HashRef,
    trigger   => \&_check_options,
    predicate => 1,
);

sub _check_options {
    my ( $self, $options ) = @_;
    return 1 unless defined $options;

    my @supported_options = (
        qw/content_type agent user_agent content_length
          path_info/
    );
    for my $opt ( keys %{$options} ) {
        croak "Not a valid option for route matching: `$opt'"
          if not( grep {/^$opt$/} @supported_options );
    }
    return 1;
}

# private attributes

has _should_capture => (
    is  => 'ro',
    isa => Bool,
);

has _match_data => (
    is      => 'rw',
    isa     => HashRef,
    trigger => sub {
        my ( $self, $value ) = @_;
    },
);

has _params => (
    is      => 'ro',
    isa     => ArrayRef,
    default => sub { [] },
);

=method match

Try to match the route with a given pair of method/path.
Returns the hash of matching data if success (captures and values of the route
against the path) or undef if not.

    my $match = $route->match( get => '/hello/sukria' );

=cut

sub match {
    my ( $self, $request ) = @_;

    if ( $self->has_options ) {
        return unless $self->validate_options($request);
    }

    my %params;
    my @values = $request->path =~ $self->regexp;

    # the regex comments are how we know if we captured
    # a splat or a megasplat
    if ( my @splat_or_megasplat = $self->regexp =~ /\(\?#((?:mega)?splat)\)/g )
    {
        for (@values) {
            $_ = [ split '/' => $_ ]
              if ( shift @splat_or_megasplat ) =~ /megasplat/;
        }
    }

    # if some named captures are found, return captures
    # no warnings is for perl < 5.10
    if (my %captures =
        do { no warnings; %+ }
      )
    {
        return $self->_match_data( { captures => \%captures } );
    }

    return unless @values;

    # save the route pattern that matched
    # TODO : as soon as we have proper Dancer2::Internal, we should remove
    # that, it's just a quick hack for plugins to access the matching
    # pattern.
    # NOTE: YOU SHOULD NOT USE THAT, OR IF YOU DO, YOU MUST KNOW
    # IT WILL MOVE VERY SOON
    # $request->{_route_pattern} = $self->regexp;

    # named tokens
    my @tokens = @{ $self->_params };

    if (@tokens) {
        for ( my $i = 0; $i < @tokens; $i++ ) {
            $params{ $tokens[$i] } = $values[$i];
        }
        return $self->_match_data( \%params );
    }

    elsif ( $self->_should_capture ) {
        return $self->_match_data( { splat => \@values } );
    }

    return $self->_match_data( {} );
}

=method execute

Runs the coderef of the route.

=cut

sub execute {
    my ( $self, @args ) = @_;
    return $self->code->(@args);
}

# private subs

sub BUILDARGS {
    my ( $class, %args ) = @_;

    my $prefix = $args{prefix};
    my $regexp = $args{regexp};

    # regexp must have a leading /
    if ( ref($regexp) ne 'Regexp' ) {
        index( $regexp, '/', 0 ) == 0
            or die "regexp must begin with /\n";
    }

    # init prefix
    if ( $prefix ) {
        $args{regexp} =
            ref($regexp) eq 'Regexp' ? qr{\Q${prefix}\E${regexp}} :
            $regexp eq '/'           ? qr{^\Q${prefix}\E/?$}      :
            $prefix . $regexp;
    }

    # init regexp
    $regexp = $args{regexp}; # updated value
    $args{spec_route} = $regexp;

    if ( ref($regexp) eq 'Regexp') {
        $args{_should_capture} = 1;
    }
    else {
        @args{qw/ regexp _params _should_capture/} =
            @{ _build_regexp_from_string($regexp) };
    }

    return \%args;
}

sub _build_regexp_from_string {
    my ($string) = @_;

    my $capture = 0;
    my @params;

    # look for route with params (/hello/:foo)
    if ( $string =~ /:/ ) {
        @params = $string =~ /:([^\/\.\?]+)/g;
        if (@params) {
            $string =~ s/(:[^\/\.\?]+)/\(\[\^\/\]\+\)/g;
            $capture = 1;
        }
    }

    # parse megasplat
    # we use {0,} instead of '*' not to fall in the splat rule
    # same logic for [^\n] instead of '.'
    $capture = 1 if $string =~ s!\Q**\E!(?#megasplat)([^\n]+)!g;

    # parse wildcards
    $capture = 1 if $string =~ s!\*!(?#splat)([^/]+)!g;

    # escape dots
    $string =~ s/\./\\\./g if $string =~ /\./;

    # escape slashes
    $string =~ s/\//\\\//g;

    return [ "^$string\$", \@params, $capture ];
}

sub validate_options {
    my ( $self, $request ) = @_;

    while ( my ( $option, $value ) = each %{ $self->options } ) {
        return 0
          if ( not $request->$option ) || ( $request->$option !~ $value );
    }
    return 1;
}

1;
