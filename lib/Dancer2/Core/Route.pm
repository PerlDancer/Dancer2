package Dancer2::Core::Route;
# ABSTRACT: Dancer2's route handler

use Moo;
use Dancer2::Core::Types;
use Carp 'croak';
use List::Util 'first';
use Scalar::Util 'blessed';

our ( $REQUEST, $RESPONSE, $RESPONDER, $WRITER, $ERROR_HANDLER );

has method => (
    is       => 'ro',
    isa      => Dancer2Method,
    required => 1,
);

has code => (
    is       => 'ro',
    required => 1,
    isa      => CodeRef,
);

has regexp => (
    is       => 'ro',
    required => 1,
);

has spec_route => ( is => 'ro' );

has prefix => (
    is        => 'ro',
    isa       => Maybe [Dancer2Prefix],
    predicate => 1,
);

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
);

has _params => (
    is      => 'ro',
    isa     => ArrayRef,
    default => sub { [] },
);

sub match {
    my ( $self, $request ) = @_;

    if ( $self->has_options ) {
        return unless $self->validate_options($request);
    }

    my @values = $request->dispatch_path =~ $self->regexp;

    # if some named captures are found, return captures
    # no warnings is for perl < 5.10
    if (my %captures =
        do { no warnings; %+ }
      )
    {
        return $self->_match_data( { captures => \%captures } );
    }

    return unless @values;

    # regex comments are how we know if we captured a token,
    # splat or a megasplat
    my @token_or_splat = $self->regexp =~ /\(\?#(token|(?:mega)?splat)\)/g;
    if (@token_or_splat) {
        # our named tokens
        my @tokens = @{ $self->_params };

        my %params;
        my @splat;
        for ( my $i = 0; $i < @values; $i++ ) {
            # Is this value from a token?
            if ( $token_or_splat[$i] eq 'token' ) {
                $params{ shift @tokens } = $values[$i];
                 next;
            }

            # megasplat values are split on '/'
            if ($token_or_splat[$i] eq 'megasplat') {
                $values[$i] = [
                    defined $values[$i] ? split( '/' , $values[$i], -1 ) : ()
                ];
            }
            push @splat, $values[$i];
        }
        return $self->_match_data( {
            %params,
            (splat => \@splat)x!! @splat,
        });
    }

    if ( $self->_should_capture ) {
        return $self->_match_data( { splat => \@values } );
    }

    return $self->_match_data( {} );
}

sub execute {
    my ( $self, $app, @args ) = @_;
    local $REQUEST  = $app->request;
    local $RESPONSE = $app->response;

    my $content = $self->code->( $app, @args );

    # users may set content in the response. If the response has
    # content, and the returned value from the route code is not
    # an object (well, reference) we ignore the returned value
    # and use the existing content in the response instead.
    $RESPONSE->has_content && !ref $content
        and return $app->_prep_response( $RESPONSE );

    my $type = blessed($content)
        or return $app->_prep_response( $RESPONSE, $content );

    # Plack::Response: proper ArrayRef-style response
    $type eq 'Plack::Response'
        and $RESPONSE = Dancer2::Core::Response->new_from_plack($RESPONSE);

    # CodeRef: raw PSGI response
    # do we want to allow it and forward it back?
    # do we want to upgrade it to an asynchronous response?
    $type eq 'CODE'
        and die "We do not support returning code references from routes.\n";

    # Dancer2::Core::Response, Dancer2::Core::Response::Delayed:
    # proper responses
    $type eq 'Dancer2::Core::Response'
        and return $RESPONSE;

    $type eq 'Dancer2::Core::Response::Delayed'
        and return $content;

    # we can't handle arrayref or hashref
    # because those might be serialized back
    die "Unrecognized response type from route: $type.\n";
}

# private subs

sub BUILDARGS {
    my ( $class, %args ) = @_;

    my $prefix = $args{prefix};
    my $regexp = $args{regexp};

    # init prefix
    if ( $prefix ) {
        $args{regexp} =
            ref($regexp) eq 'Regexp' ? qr{^\Q${prefix}\E${regexp}$} :
            $prefix . $regexp;
    }
    elsif ( ref($regexp) ne 'Regexp' ) {
        # No prefix, so ensure regexp begins with a '/'
        index( $regexp, '/', 0 ) == 0 or $args{regexp} = "/$regexp";
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

    # look for route with tokens [aka params] (/hello/:foo)
    if ( $string =~ /:/ ) {
        @params = $string =~ /:([^\/\.\?]+)/g;
        if (@params) {
            first { $_ eq 'splat' } @params
                and warn q{Named placeholder 'splat' is deprecated};

            first { $_ eq 'captures' } @params
                and warn q{Named placeholder 'captures' is deprecated};

            $string =~ s!(:[^\/\.\?]+)!(?#token)([^/]+)!g;
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

    for my $option ( keys %{ $self->options } ) {
        return 0
          if (
            ( not $request->$option )
            || ( $request->$option !~ $self->options->{ $option } )
          )
    }
    return 1;
}

1;

__END__

=attr method

The HTTP method of the route (lowercase). Required.

=attr code

The code reference to execute when the route is ran. Required.

=attr regexp

The regular expression that defines the path of the route.
Required. Coerce from Dancer2's route I<patterns>.

=attr prefix

The prefix to prepend to the C<regexp>. Optional.

=attr options

A HashRef of conditions on which the matching will depend. Optional.

=method match

Try to match the route with a given pair of method/path.
Returns the hash of matching data if success (captures and values of the route
against the path) or undef if not.

    my $match = $route->match( get => '/hello/sukria' );

=method execute

Runs the coderef of the route.

=cut
