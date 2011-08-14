package Dancer::Core::Route;

use strict;
use warnings;

use Moo;
use Dancer::Moo::Types;

use Carp;

use Dancer::App;
use Dancer::Logger;
use Dancer::Config 'setting';
use Dancer::Request;
use Dancer::Response;

has method => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::DancerMethod(@_) },
    required => 1,
);

1;
__END__

has prefix => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::DancerPrefix(@_) },
);

has code => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::CodeRef(@_) },
);

has prev => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::ObjectOf( 'Dancer::Route' => @_) },
);

has next => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::ObjectOf( 'Dancer::Route' => @_) },
);

has options => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::HashRef( @_) },
    trigger => \&_check_options,
);

sub _check_options {
    my ($self, $options) = @_;

    my @_supported_options = Dancer::Request->get_attributes();
    my %_options_aliases = (agent => 'user_agent');

    return 1 unless defined $options;

    for my $opt (keys %{$options}) {
        croak "Not a valid option for route matching: `$opt'"
          if not(    (grep {/^$opt$/} @{$_supported_options[0]})
                  || (grep {/^$opt$/} keys(%_options_aliases)));
    }
    return 1;
}

has should_capture => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::Bool(@_) },
);

has match_data => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::HashRef( @_) },
);

has params => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::ArrayRef(@_) },
    default => sub { [] },
);

# backward compat
has pattern => (
    is => 'ro',
    trigger => sub { $_[0]->regexp($_[1] ) },
);

has regexp => (
    is => 'ro',
    required => 1,
    
    # we may have non-regexp value here, Dancer route patterns
    # then, we must coerce them into plain Regexp
    trigger => sub {  
        my ($self, $value) = @_;

        # already a Regexp, so capture is true
        if (ref($value) eq 'Regexp') {
            my $regexp = $self->regexp;
            $self->regexp(qr{^$regexp$});
            $self->should_capture(1);
            return $value;
        }

        my ($compiled, $params, $should_capture) = 
          @{ _build_regexp_from_string(@_) };

        $self->should_capture(defined $should_capture ? $should_capture : 0 );
        $self->params($params || []);
        $self->{regexp} = $compiled;

        return $compiled;
    },
);

sub BUILD {
    my ($self) = @_;

    # prepend the prefix to the regexp if any
    if (defined $self->prefix) {
        my $prefix = $self->prefix;
        my $regexp = $self->regexp;

        if ($regexp !~ /^$prefix/) {
            $self->regexp(qr{${prefix}${regexp}});
        }
    }

    $self->set_previous($self->prev) if $self->prev;

    return $self;
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

    return ["^${string}\$", \@params, $capture];
}

sub set_previous {
    my ($self, $prev) = @_;

    $self->prev($prev);
    $self->prev->next( $self );

    return $prev;
}

sub save_match_data {
    my ($self, $request, $match_data) = @_;
    $self->match_data($match_data);
    $request->_set_route_params($match_data);

    return $match_data;
}

# Does the route match the request
sub match {
    my ($self, $request) = @_;

    my $method = lc($request->method);
    my $path   = $request->path_info;
    my %params;

    Dancer::Logger::core("trying to match `$path' "
          . "against /"
          . $self->regexp
          . "/");

    my @values = $path =~ $self->regexp;

    # the regex comments are how we know if we captured
    # a splat or a megasplat
    if( my @splat_or_megasplat
            = $self->regexp =~ /\(\?#((?:mega)?splat)\)/g ) {
        for ( @values ) {
            $_ = [ split '/' => $_ ] if ( shift @splat_or_megasplat ) =~ /megasplat/;
        }
    }

    Dancer::Logger::core("  --> got ".
        map { defined $_ ? $_ : 'undef' } @values)
        if @values;

    # if some named captures found, return captures
    # no warnings is for perl < 5.10
    if (my %captures =
        do { no warnings; %+ }
      )
    {
        Dancer::Logger::core(
            "  --> captures are: " . join(", ", keys(%captures)))
          if keys %captures;
        return $self->save_match_data($request, {captures => \%captures});
    }

    return unless @values;

    # save the route pattern that matched
    # TODO : as soon as we have proper Dancer::Internal, we should remove
    # that, it's just a quick hack for plugins to access the matching
    # pattern.
    # NOTE: YOU SHOULD NOT USE THAT, OR IF YOU DO, YOU MUST KNOW
    # IT WILL MOVE VERY SOON
    $request->{_route_pattern} = $self->regexp;

    # named tokens
    my @tokens = @{$self->params};

    Dancer::Logger::core("  --> named tokens are: @tokens") if @tokens;
    if (@tokens) {
        for (my $i = 0; $i < @tokens; $i++) {
            $params{$tokens[$i]} = $values[$i];
        }
        return $self->save_match_data($request, \%params);
    }

    elsif ($self->should_capture) {
        return $self->save_match_data($request, {splat => \@values});
    }

    return $self->save_match_data($request, {});
}

sub run {
    my ($self, $request, $response) = @_;

    my $content  = $self->execute();
#    my $response = Dancer::SharedData->response;

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

sub find_next_matching_route {
    my ($self, $request) = @_;
    my $next = $self->next;
    return unless $next;

    return $next if $next->match($request);
    return $next->find_next_matching_route($request);
}

sub execute {
    my ($self) = @_;

    if (Dancer::Config::setting('warnings')) {
        my $warning;
        local $SIG{__WARN__} = sub { $warning = $_[0] };
        my $content = $self->code->();
        if ($warning) {
            return Dancer::Error->new(
                code    => 500,
                message => "Warning caught during route execution: $warning",
            )->render;
        }
        return $content;
    }
    else {
        return $self->code->();
    }
}

sub equals {
    my ($self, $route) = @_;
    return $self->regexp eq $route->regexp;
}


1;
