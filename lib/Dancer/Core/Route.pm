package Dancer::Core::Route;
# ABSTRACT: class for Dancer route handler objects

use strict;
use warnings;

use Moo;
use Dancer::Moo::Types;
use Carp 'croak';

=attr method

the HTTP method of the route (lowercase). Required.

=cut

has method => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::DancerMethod(@_) },
    required => 1,
);

=attr code

The code reference to execute when the route is ran. Required.

=cut

has code => (
    is => 'ro',
    required => 1,
    isa => sub { Dancer::Moo::Types::CodeRef(@_) },
);

=attr regexp

The regular expression that defines the path of the route.
Required. Coerce from Dancer's route I<patterns>.

=cut

has regexp => (
    is => 'rw',
    required => 1,
);

# route handlers are chained, this is very handy for the pass feature 
has next => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::ObjectOf('Dancer::Core::Route', @_) },
);

has previous => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::ObjectOf('Dancer::Core::Route', @_) },
    trigger => sub {
        my ($self, $previous) = @_;
        $previous->next($self);
    },
);

=attr prefix

The prefix to prepend to the C<regexp>. Optional.

=cut

has prefix => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::DancerPrefix(@_) },
);

=attr options 

A HashRef of conditions on which the matching will depend. Optional.

=cut

has options => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::HashRef( @_) },
    trigger => \&_check_options,
);

# TODO this should be done elsewhere
#sub _check_options {
#    my ($self, $options) = @_;
#
##  TODO  my @_supported_options = Dancer::Request->get_attributes();
#    my @_supported_options;
#    my %_options_aliases = (agent => 'user_agent');
#
#    return 1 unless defined $options;
#
#    for my $opt (keys %{$options}) {
#        croak "Not a valid option for route matching: `$opt'"
#          if not(    (grep {/^$opt$/} @{$_supported_options[0]})
#                  || (grep {/^$opt$/} keys(%_options_aliases)));
#    }
#    return 1;
#}
#
# private attributes

has _should_capture => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::Bool(@_) },
);

has _match_data => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::HashRef( @_) },
    trigger => sub {
        my ($self, $value) = @_;
    },
);

has _params => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::ArrayRef(@_) },
    default => sub { [] },
);

=method match

Try to match the route with a given pair of method/path.
Returns the hash of matching data if success (captures and values of the route
against the path) or undef if not.

    my $match = $route->match( get => '/hello/sukria' );

=cut

sub match {
    my ($self, $method, $path) = @_;

    my %params;
    my @values = $path =~ $self->regexp;

    # the regex comments are how we know if we captured
    # a splat or a megasplat
    if( my @splat_or_megasplat
            = $self->regexp =~ /\(\?#((?:mega)?splat)\)/g ) {
        for ( @values ) {
            $_ = [ split '/' => $_ ] if ( shift @splat_or_megasplat ) =~ /megasplat/;
        }
    }

    # if some named captures found, return captures
    # no warnings is for perl < 5.10
    if (my %captures =
        do { no warnings; %+ }
      )
    {
        return $self->_match_data({captures => \%captures});
    }

    return unless @values;

    # save the route pattern that matched
    # TODO : as soon as we have proper Dancer::Internal, we should remove
    # that, it's just a quick hack for plugins to access the matching
    # pattern.
    # NOTE: YOU SHOULD NOT USE THAT, OR IF YOU DO, YOU MUST KNOW
    # IT WILL MOVE VERY SOON
    # $request->{_route_pattern} = $self->regexp;

    # named tokens
    my @tokens = @{$self->_params};

    if (@tokens) {
        for (my $i = 0; $i < @tokens; $i++) {
            $params{$tokens[$i]} = $values[$i];
        }
        return $self->_match_data(\%params);
    }

    elsif ($self->_should_capture) {
        return $self->_match_data({splat => \@values});
    }

    return $self->_match_data({});
}

=method execute

Runs the coderef of the route

=cut

sub execute {
    my ($self, @args) = @_;
    return $self->code->(@args);
}

# private subs

sub BUILD {
    my ($self) = @_;

    # prepend the prefix to the regexp if any
    # this is done in BUILD instead of a trigger in order to be sure that the regexp
    # attribute is set when this is ran.
    $self->_init_prefix if defined $self->prefix;

    # now we can build the regexp
    $self->_init_regexp;
}

# alter the regexp according to the prefix set, if any.
sub _init_prefix {
    my ($self) = @_;
    
    my $prefix = $self->prefix;
    my $regexp = $self->regexp;

# NOTE apparently this cannot work
#    if (ref($regexp) eq 'Regexp') {
#        return $self->regexp(qr{${prefix}${regexp}}) 
#          if $regexp !~ /^$prefix/;
#        return;
#    }
    
    if (ref($regexp) eq 'Regexp') {
        croak "Cannot combine a prefix ($prefix) with a regular expression ($regexp)";
    }

    if ($self->regexp eq '/') {

        # if pattern is '/', we should match:
        # - /prefix/
        # - /prefix
        # this is done by creating a regex for this case
        my $qpattern = quotemeta( $self->regexp);
        my $qprefix  = quotemeta( $self->prefix );
        my $new_regxp = qr/^$qprefix(?:$qpattern)?$/;

        return $self->regexp( $new_regxp );
    }

    return $self->regexp($prefix . $self->regexp);
}

sub _init_regexp {
    my ($self) = @_;
    my $value = $self->regexp;

    # already a Regexp, so capture is true
    if (ref($value) eq 'Regexp') {
        $self->_should_capture(1);
        return $value;
    }

    my ($compiled, $params, $should_capture) =
      @{_build_regexp_from_string($value)};

    $self->_should_capture($should_capture);
    $self->_params($params || []);
    $self->regexp( $compiled );
}

sub _build_regexp_from_string {
    my ($string) = @_;

    my $capture = 0;
    my @params;

    # look for route with params (/hello/:foo)
    if ($string =~ /:/) {
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

    return ["^$string\$", \@params, $capture];
}

1;
__END__

# TODO this should be moved in an upper layer
 
sub run {
    my ($self, $request, $response) = @_;

    my $content  = $self->execute();

    if ( $response && $response->is_forwarded ) {
        my $new_req =
            Dancer::Request->forward($request, $response->{forward});
        my $marshalled = Dancer::Handler->handle_request($new_req);

        return Dancer::Response->new(
            encoded => 1,
            status  => $marshalled->[0],
            headers => $marshalled->[1],
            # if the forward failed with 404, marshalled->[2] is not an array, but a GLOB
            content => ref($marshalled->[2]) eq "ARRAY" ? @{ $marshalled->[2] } : $marshalled->[2]
        );
    }

    if ($response && $response->has_passed) {
        $response->pass(0);
        if ($self->next) {
            my $next_route = $self->find_next_matching_route($request);
            return $next_route->run($request, $response);
        }
        else {
            Dancer::Logger::core('Last matching route passed!');
            return undef;
        }
    }

    # coerce undef content to empty string to
    # prevent warnings
    $content = (defined $content) ? $content : '';

    my $ct =
      ( defined $response && defined $response->content_type )
      ? $response->content_type()
      : setting('content_type');

    my $st = defined $response ? $response->status : 200;

    my $headers = [];
    push @$headers, @{ $response->headers_to_array } if defined $response;

    # content type may have already be set earlier
    # (eg: with send_error)
    push(@$headers, 'Content-Type' => $ct)
      unless grep {/Content-Type/} @$headers;

    return $content if ref($content) eq 'Dancer::Response';
    return Dancer::Response->new(
        status       => $st,
        headers      => $headers,
        content      => $content,
    );
}


