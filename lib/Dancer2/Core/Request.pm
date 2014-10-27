package Dancer2::Core::Request;

# ABSTRACT: Interface for accessing incoming requests

use Moo;

use Carp;
use Encode;
use HTTP::Body;
use URI;
use URI::Escape;
use Class::Load 'try_load_class';

use Dancer2::Core::Types;
use Dancer2::Core::Request::Upload;
use Dancer2::Core::Cookie;

with 'Dancer2::Core::Role::Headers';

# add an attribute for each HTTP_* variables
# (HOST is managed manually)
my @http_env_keys = (qw/
    accept
    accept_charset
    accept_encoding
    accept_language
    accept_type
    connection
    keep_alive
    referer
    user_agent
    x_requested_with
/);

foreach my $attr ( @http_env_keys ) {
    has $attr => (
        is      => 'ro',
        isa     => Maybe[Str],
        lazy    => 1,
        default => sub { $_[0]->env->{ 'HTTP_' . ( uc $attr ) } },
    );
}

# check presence of XS module to speedup request
our $XS_URL_DECODE         = try_load_class('URL::Encode::XS');
our $XS_PARSE_QUERY_STRING = try_load_class('CGI::Deurl::XS');

# then all the native attributes
has env => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

# a buffer for per-request variables
has vars => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

sub var {
    my $self = shift;
    @_ == 2
      ? $self->vars->{ $_[0] } = $_[1]
      : $self->vars->{ $_[0] };
}

has path => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_path',
);

sub _build_path {
    my $self = shift;

    # Written from PSGI specs:
    # http://search.cpan.org/dist/PSGI/PSGI.pod

    my $path = "";

    $path .= $self->script_name if defined $self->script_name;
    $path .= $self->env->{PATH_INFO} if defined $self->env->{PATH_INFO};

    # fallback to REQUEST_URI if nothing found
    # we have to decode it, according to PSGI specs.
    if ( defined $self->request_uri ) {
        $path ||= $self->_url_decode( $self->request_uri );
    }

    croak "Cannot resolve path" if not $path;

    return $path;
}

has path_info => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    writer  => 'set_path_info',
    builder => '_build_path_info',
);

sub _build_path_info {
    my $self = shift;

    my $info = $self->env->{PATH_INFO};

    # Empty path info will be interpreted as "root".
    return $info || '/' if defined $info;

    return $self->path;
}

has method => (
    is      => 'rw',
    isa     => Dancer2HTTPMethod,
    default => sub {
        my $self = shift;
        $self->env->{REQUEST_METHOD} || 'GET';
    },
    coerce => sub { uc $_[0] },
);

has content_type => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    default => sub {
        $_[0]->env->{CONTENT_TYPE} || '';
    },
);

has content_length => (
    is      => 'ro',
    isa     => Num,
    lazy    => 1,
    default => sub {
        $_[0]->env->{CONTENT_LENGTH} || 0;
    },
);

has body => (
    is      => 'ro',
    isa     => Str,
    default => sub {''},
);

has id => (
    is  => 'ro',
    isa => Num,
);

# Private 'read-only' attributes for request params. See the params()
# method for the public interface.
#
# _body_params, _query_params and _route_params have setter methods that
# decode byte string to characters before setting; If you know you have
# decoded (character) params, such as output from a deserializer, you can
# set these directly in the request object hash to avoid the decode op.

has _params => (
    is        => 'lazy',
    isa       => HashRef,
    builder   => '_build_params',
    predicate => '_has_params',
);

has _body_params => (
    is      => 'ro',
    isa     => Maybe( HashRef ),
    default => sub {undef},
);

sub _set_body_params {
    my ( $self, $params ) = @_;
    $self->{_body_params} = _decode( $params );
    $self->_build_params();
}

has _query_params => (
    is      => 'ro',
    isa     => Maybe( HashRef ),
    default => sub {undef},
);

sub _set_query_params {
    my ( $self, $params ) = @_;
    $self->{_query_params} = _decode( $params );
    $self->_build_params();
}

has _route_params => (
    is      => 'ro',
    isa     => HashRef,
    default => sub {{}},
);

sub _set_route_params {
    my ( $self, $params ) = @_;
    $self->{_route_params} = _decode( $params );
    $self->_build_params();
}

has uploads => (
    is  => 'ro',
    isa => HashRef,
);

has body_is_parsed => (
    is      => 'ro',
    isa     => Bool,
    default => sub {0},
);

has is_behind_proxy => (
    is      => 'ro',
    isa     => Bool,
    lazy    => 1,
    default => sub {0},
);

sub host {
    my ($self) = @_;

    if ( $self->is_behind_proxy ) {
        my @hosts = split /\s*,\s*/, $self->env->{HTTP_X_FORWARDED_HOST}, 2;
        return $hosts[0];
    } else {
        return $self->env->{'HTTP_HOST'};
    }
}

# aliases, kept for backward compat
sub agent                 { $_[0]->user_agent }
sub remote_address        { $_[0]->address }
sub forwarded_for_address { $_[0]->env->{HTTP_X_FORWARDED_FOR} }
sub address               { $_[0]->env->{REMOTE_ADDR} }
sub remote_host           { $_[0]->env->{REMOTE_HOST} }
sub protocol              { $_[0]->env->{SERVER_PROTOCOL} }
sub port                  { $_[0]->env->{SERVER_PORT} }
sub request_uri           { $_[0]->env->{REQUEST_URI} }
sub user                  { $_[0]->env->{REMOTE_USER} }
sub script_name           { $_[0]->env->{SCRIPT_NAME} }

sub scheme {
    my ($self) = @_;
    my $scheme;
    if ( $self->is_behind_proxy ) {
        # Note the 'HTTP_' prefix the PSGI spec adds to headers.
        $scheme =
             $self->env->{'HTTP_X_FORWARDED_PROTOCOL'}
          || $self->env->{'HTTP_X_FORWARDED_PROTO'}
          || $self->env->{'HTTP_FORWARDED_PROTO'}
          || "";
    }
    return
         $scheme
      || $self->env->{'psgi.url_scheme'}
      || $self->env->{'PSGI.URL_SCHEME'}
      || "";
}

has serializer => (
    is        => 'ro',
    isa       => Maybe( ConsumerOf ['Dancer2::Core::Role::Serializer'] ),
    predicate => 1,
);

has data => (
    is      => 'ro',
    lazy    => 1,
    default => \&deserialize,
);

sub deserialize {
    my $self = shift;

    return unless $self->has_serializer;

    # Content-Type may contain additional parameters
    # (http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.7)
    # which should be safe to ignore at this level.
    # So accept either e.g. text/xml or text/xml; charset=utf-8
    my ($content_type) = split /\s*;/, $self->content_type, 2;

    return unless $self->serializer->support_content_type($content_type);

    # The latest draft of the RFC does not forbid DELETE to have content,
    # rather the behaviour is undefined. Take the most lenient route and
    # deserialize any content on delete as well.
    return
      unless grep { $self->method eq $_ } qw/ PUT POST PATCH DELETE /;

    # try to deserialize
    my $body = $self->_read_to_end();
    my $data = $self->serializer->deserialize($self->body);
    return if !defined $data;

    # Set _body_params directly rather than using the setter. Deserializiation
    # returns characters and skipping the decode op in the setter ensures
    # that numerical data "stays" numerical; decoding an SV that is an IV
    # converts that to a PVIV. Some serializers are picky (JSON)..
    $self->{_body_params} = $data;
    $self->_build_params();

    return $data;
}

sub secure    { $_[0]->scheme   eq 'https' }
sub uri       { $_[0]->request_uri }
sub is_head   { $_[0]->{method} eq 'HEAD' }
sub is_post   { $_[0]->{method} eq 'POST' }
sub is_get    { $_[0]->{method} eq 'GET' }
sub is_put    { $_[0]->{method} eq 'PUT' }
sub is_delete { $_[0]->{method} eq 'DELETE' }
sub is_patch  { $_[0]->{method} eq 'PATCH' }

# public interface compat with CGI.pm objects
sub request_method { method(@_) }
sub input_handle { $_[0]->env->{'psgi.input'} || $_[0]->env->{'PSGI.INPUT'} }

our $_count = 0;

sub BUILD {
    my ($self) = @_;

    $self->{id} = ++$_count;

    $self->{_chunk_size}    = 4096;
    $self->{_read_position} = 0;

    $self->_init_request_headers();

    $self->{_http_body} =
      HTTP::Body->new( $self->content_type, $self->content_length );
    $self->{_http_body}->cleanup(1);

    $self->data;      # Deserialize body
    $self->_params(); # Decode query and body prams
    $self->_build_uploads();
}

sub to_string {
    my ($self) = @_;
    return "[#" . $self->id . "] " . $self->method . " " . $self->path;
}

sub base {
    my $self = shift;
    my $uri  = $self->_common_uri;

    return $uri->canonical;
}

sub _common_uri {
    my $self = shift;

    my $path   = $self->env->{SCRIPT_NAME};
    my $port   = $self->env->{SERVER_PORT};
    my $server = $self->env->{SERVER_NAME};
    my $host   = $self->host;
    my $scheme = $self->scheme;

    my $uri = URI->new;
    $uri->scheme($scheme);
    $uri->authority( $host || "$server:$port" );
    $uri->path( $path      || '/' );

    return $uri;
}

sub uri_base {
    my $self  = shift;
    my $uri   = $self->_common_uri;
    my $canon = $uri->canonical;

    if ( $uri->path eq '/' ) {
        $canon =~ s{/$}{};
    }

    return $canon;
}

sub dispatch_path {
    my $self = shift;

    my $path = $self->path;

    # Want $self->base->path, without needing the URI object,
    # and trim any trailing '/'.
    my $base = '';
    $base .= $self->script_name if defined $self->script_name;
    $base =~ s|/+$||;

    # Remove base from front of path.
    $path =~ s|^(\Q$base\E)?||;
    $path =~ s|^/+|/|;
    # PSGI spec notes that '' should be considered '/'
    $path = '/' if $path eq '';
    return $path;
}

sub uri_for {
    my ( $self, $part, $params, $dont_escape ) = @_;

    my $uri = $self->base;

    # Make sure there's exactly one slash between the base and the new part
    my $base = $uri->path;
    $base =~ s|/$||;
    $part =~ s|^/||;
    $uri->path("$base/$part");

    $uri->query_form($params) if $params;

    return $dont_escape ? uri_unescape( $uri->canonical ) : $uri->canonical;
}

sub params {
    my ( $self, $source ) = @_;

    return %{ $self->_params } if wantarray && @_ == 1;
    return $self->_params if @_ == 1;

    if ( $source eq 'query' ) {
        return %{ $self->_query_params || {} } if wantarray;
        return $self->_query_params;
    }
    elsif ( $source eq 'body' ) {
        return %{ $self->_body_params || {} } if wantarray;
        return $self->_body_params;
    }
    if ( $source eq 'route' ) {
        return %{ $self->_route_params } if wantarray;
        return $self->_route_params;
    }
    else {
        croak "Unknown source params \"$source\".";
    }
}

sub captures { shift->params->{captures} }

sub splat { @{ shift->params->{splat} || [] } }

sub param { shift->params->{ $_[0] } }

sub _decode {
    my ($h) = @_;
    return if not defined $h;

    if ( !ref($h) && !utf8::is_utf8($h) ) {
        return decode( 'UTF-8', $h );
    }

    if ( ref($h) eq 'HASH' ) {
        while ( my ( $k, $v ) = each(%$h) ) {
            $h->{$k} = _decode($v);
        }
        return $h;
    }

    if ( ref($h) eq 'ARRAY' ) {
        return [ map { _decode($_) } @$h ];
    }

    return $h;
}

sub is_ajax {
    my $self = shift;

    return 0 unless defined $self->headers;
    return 0 unless defined $self->header('X-Requested-With');
    return 0 if $self->header('X-Requested-With') ne 'XMLHttpRequest';
    return 1;
}

# context-aware accessor for uploads
sub upload {
    my ( $self, $name ) = @_;
    my $res = $self->{uploads}{$name};

    return $res unless wantarray;
    return ()   unless defined $res;
    return ( ref($res) eq 'ARRAY' ) ? @$res : $res;
}

sub _build_params {
    my ($self) = @_;

    # params may have been populated by before filters
    # _before_ we get there, so we have to save it first
    my $previous = $self->_has_params ? $self->_params : {};

    # now parse environment params...
    $self->_parse_get_params();
    if ( $self->body_is_parsed ) {
        $self->{_body_params} ||= {};
    }
    else {
        $self->_parse_post_params();
    }

    # and merge everything
    $self->{_params} = {
        %$previous,                %{ $self->_query_params || {} },
        %{ $self->_route_params }, %{ $self->_body_params  || {} },
    };

}

sub _url_decode {
    my ( $self, $encoded ) = @_;
    return URL::Encode::XS::url_decode($encoded) if $XS_URL_DECODE;
    my $clean = $encoded;
    $clean =~ tr/\+/ /;
    $clean =~ s/%([a-fA-F0-9]{2})/pack "H2", $1/eg;
    return $clean;
}

sub _parse_post_params {
    my ($self) = @_;
    return $self->_body_params if defined $self->_body_params;

    my $body = $self->_read_to_end();
    $self->_set_body_params( $self->{_http_body}->param );
}

sub _parse_get_params {
    my ($self) = @_;
    return $self->_query_params if defined $self->{_query_params};

    my $query_params = {};

    my $source = $self->env->{QUERY_STRING};
    return if !defined $source || $source eq '';

    if ($XS_PARSE_QUERY_STRING) {
        $self->_set_query_params(
            CGI::Deurl::XS::parse_query_string($source) || {}
        );
        return $self->_query_params;
    }

    foreach my $token ( split /[&;]/, $source ) {
        my ( $key, $val ) = split( /=/, $token );
        next unless defined $key;
        $val = ( defined $val ) ? $val : '';
        $key = $self->_url_decode($key);
        $val = $self->_url_decode($val);

        # looking for multi-value params
        if ( exists $query_params->{$key} ) {
            my $prev_val = $query_params->{$key};
            if ( ref($prev_val) && ref($prev_val) eq 'ARRAY' ) {
                push @{ $query_params->{$key} }, $val;
            }
            else {
                $query_params->{$key} = [ $prev_val, $val ];
            }
        }

        # simple value param (first time we see it)
        else {
            $query_params->{$key} = $val;
        }
    }
    $self->_set_query_params( $query_params );
    return $self->_query_params;
}

sub _read_to_end {
    my ($self) = @_;

    my $content_length = $self->content_length;
    return unless $self->_has_something_to_read();

    if ( $content_length > 0 ) {
        while ( my $buffer = $self->_read() ) {
            $self->{body} .= $buffer;
            $self->{_http_body}->add($buffer);
        }
    }

    return $self->{body};
}

sub _has_something_to_read {
    my ($self) = @_;
    return 0 unless defined $self->input_handle;
}

# taken from Miyagawa's Plack::Request::BodyParser
sub _read {
    my ( $self, ) = @_;
    my $remaining = $self->content_length - $self->{_read_position};
    my $maxlength = $self->{_chunk_size};

    return if ( $remaining <= 0 );

    my $readlen = ( $remaining > $maxlength ) ? $maxlength : $remaining;
    my $buffer;
    my $rc;

    $rc = $self->input_handle->read( $buffer, $readlen );

    if ( defined $rc ) {
        $self->{_read_position} += $rc;
        return $buffer;
    }
    else {
        croak "Unknown error reading input: $!";
    }
}

sub _init_request_headers {
    my ($self) = @_;
    my $env = $self->env;

    $self->headers(
        HTTP::Headers->new(
            map {
                ( my $field = $_ ) =~ s/^HTTPS?_//;
                ( $field => $env->{$_} );
              }
              grep {/^(?:HTTP|CONTENT)/i} keys %$env
        )
    );
}

# Taken gently from Plack::Request, thanks to Plack authors.
sub _build_uploads {
    my ($self) = @_;

    my $uploads = _decode( $self->{_http_body}->upload );
    my %uploads;

    for my $name ( keys %{$uploads} ) {
        my $files = $uploads->{$name};
        $files = ref $files eq 'ARRAY' ? $files : [$files];

        my @uploads;
        for my $upload ( @{$files} ) {
            push(
                @uploads,
                Dancer2::Core::Request::Upload->new(
                    headers  => $upload->{headers},
                    tempname => $upload->{tempname},
                    size     => $upload->{size},
                    filename => $upload->{filename},
                )
            );
        }
        $uploads{$name} = @uploads > 1 ? \@uploads : $uploads[0];

        # support access to the filename as a normal param
        my @filenames = map { $_->{filename} } @uploads;
        $self->{_body_params}{$name} =
          @filenames > 1 ? \@filenames : $filenames[0];
    }

    $self->{uploads} = \%uploads;
    $self->_build_params();
}

has cookies => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_cookies',
);

sub _build_cookies {
    my $self    = shift;
    my $cookies = {};

    my $http_cookie = $self->header('Cookie');
    return $cookies unless defined $http_cookie; # nothing to do

    foreach my $cookie ( split( /[,;]\s/, $http_cookie ) ) {

        # here, we don't want more than the 2 first elements
        # a cookie string can contains something like:
        # cookie_name="foo=bar"
        # we want `cookie_name' as the value and `foo=bar' as the value
        my ( $name, $value ) = split( /\s*=\s*/, $cookie, 2 );
        my @values;
        if ( $value ne '' ) {
            @values = map { uri_unescape($_) } split( /[&;]/, $value );
        }
        $cookies->{$name} =
          Dancer2::Core::Cookie->new( name => $name, value => \@values );
    }
    return $cookies;
}

1;

__END__

=head1 DESCRIPTION

This class implements a common interface for accessing incoming requests in
a Dancer2 application.

=head1 SYNOPSIS

In a route handler, the current request object can be accessed by the C<request>
method, like in the following example:

    get '/foo' => sub {
        request->params; # request, params parsed as a hash ref
        request->body; # returns the request body, unparsed
        request->path; # the path requested by the client
        # ...
    };

A route handler should not read the environment by itself, but should instead
use the current request object.

=head1 Common HTTP request headers

Commonly used client-supplied HTTP request headers are available through
specific accessors, here are those supported:

=over 4

=item C<accept>

=item C<accept_charset>

=item C<accept_encoding>

=item C<accept_language>

=item C<accept_type>

=item C<agent> (alias for C<user_agent>)

=item C<connection>

=item C<forwarded_for_address>

=item C<forwarded_protocol>

=item C<forwarded_host>

=item C<host>

=item C<keep_alive>

=item C<path_info>

=item C<referer>

=item C<remote_address>

=item C<user_agent>

=item C<x_requested_with>

=back

With the exception of C<host>, these accessors are lookups into the PSGI env
hash reference.

Note that the L<PSGI> specification prefixes client-supplied request headers with
C<HTTP_>. For example, a C<X-Requested-With> header has the key
C<HTTP_X_REQUESTED_WITH> in the PSGI env hashref.

=head1 EXTRA SPEED

Install URL::Encode::XS and CGI::Deurl::XS for extra speed.

Dancer2::Core::Request will use it if they detect their presence.

=method env()

Return the current PSGI environment hash reference.

=method var

By-name interface to variables stored in this request object.

  my $stored = $request->var('some_variable');

returns the value of 'some_variable', while

  $request->var('some_variable' => 'value');

will set it.

=method path()

Return the path requested by the client.

=method method()

Return the HTTP method used by the client to access the application.

While this method returns the method string as provided by the environment, it's
better to use one of the following boolean accessors if you want to inspect the
requested method.

=method content_type()

Return the content type of the request.

=method content_length()

Return the content length of the request.

=method body()

Return the raw body of the request, unparsed.

If you need to access the body of the request, you have to use this accessor and
should not try to read C<psgi.input> by hand. C<Dancer2::Core::Request>
already did it for you and kept the raw body untouched in there.

=method uploads()

Returns a reference to a hash containing uploads. Values can be either a
L<Dancer2::Core::Request::Upload> object, or an arrayref of
L<Dancer2::Core::Request::Upload>
objects.

You should probably use the C<upload($name)> accessor instead of manually accessing the
C<uploads> hash table.

=method header($name)

Return the value of the given header, if present. If the header has multiple
values, returns an the list of values if called in list context, the first one
in scalar.


=method new()

The constructor of the class, used internally by Dancer2's core to create request
objects.

It uses the environment hash table given to build the request object:

    Dancer2::Core::Request->new(env => \%env);

It also accepts the C<body_is_parsed> boolean flag, if the new request object should
not parse request body.

=method address()

Return the IP address of the client.

=method remote_host()

Return the remote host of the client. This only works with web servers configured
to do a reverse DNS lookup on the client's IP address.

=method protocol()

Return the protocol (HTTP/1.0 or HTTP/1.1) used for the request.

=method port()

Return the port of the server.

=method request_uri()

Return the raw, undecoded request URI path.

=method user()

Return remote user if defined.

=method script_name()

Return script_name from the environment.

=method scheme()

Return the scheme of the request

=method serializer()

Returns the optional serializer object used to deserialize request parameters.

=method data()

If the application has a serializer and if the request has serialized
content, returns the deserialized structure as a hashref.

=method secure()

Return true of false, indicating whether the connection is secure

=method uri()

An alias to request_uri()

=method is_get()

Return true if the method requested by the client is 'GET'

=method is_head()

Return true if the method requested by the client is 'HEAD'

=method is_post()

Return true if the method requested by the client is 'POST'

=method is_put()

Return true if the method requested by the client is 'PUT'

=method is_delete()

Return true if the method requested by the client is 'DELETE'

=method request_method

Alias to the C<method> accessor, for backward-compatibility with C<CGI> interface.

=method input_handle

Alias to the PSGI input handle (C<< <request->env->{psgi.input}> >>)

=method to_string()

Return a string representing the request object (eg: C<"GET /some/path">)

=method base()

Returns an absolute URI for the base of the application.  Returns a L<URI>
object (which stringifies to the URL, as you'd expect).

=method uri_base()

Same thing as C<base> above, except it removes the last trailing slash in the
path if it is the only path.

This means that if your base is I<http://myserver/>, C<uri_base> will return
I<http://myserver> (notice no trailing slash). This is considered very useful
when using templates to do the following thing:

    <link rel="stylesheet" href="[% request.uri_base %]/css/style.css" />

=method dispatch_path()

The part of the C<path> after C<base>. This is the path used
for dispatching the request to routes.

=method uri_for(path, params)

Constructs a URI from the base and the passed path.  If params (hashref) is
supplied, these are added to the query string of the uri.  If the base is
C<http://localhost:5000/foo>, C<< request->uri_for('/bar', { baz => 'baz' }) >>
would return C<http://localhost:5000/foo/bar?baz=baz>.  Returns a L<URI> object
(which stringifies to the URL, as you'd expect).

=method params($source)

Called in scalar context, returns a hashref of params, either from the specified
source (see below for more info on that) or merging all sources.

So, you can use, for instance:

    my $foo = params->{foo}

If called in list context, returns a list of key => value pairs, so you could use:

    my %allparams = params;


=head3 Fetching only params from a given source

If a required source isn't specified, a mixed hashref (or list of key value
pairs, in list context) will be returned; this will contain params from all
sources (route, query, body).

In practical terms, this means that if the param C<foo> is passed both on the
querystring and in a POST body, you can only access one of them.

If you want to see only params from a given source, you can say so by passing
the C<$source> param to C<params()>:

    my %querystring_params = params('query');
    my %route_params       = params('route');
    my %post_params        = params('body');

If source equals C<route>, then only params parsed from the route pattern
are returned.

If source equals C<query>, then only params parsed from the query string are
returned.

If source equals C<body>, then only params sent in the request body will be
returned.

If another value is given for C<$source>, then an exception is triggered.

=method is_ajax()

Return true if the value of the header C<X-Requested-With> is XMLHttpRequest.

=method upload($name)

Context-aware accessor for uploads. It's a wrapper around an access to the hash
table provided by C<uploads()>. It looks at the calling context and returns a
corresponding value.

If you have many file uploads under the same name, and call C<upload('name')> in
an array context, the accessor will unroll the ARRAY ref for you:

    my @uploads = request->upload('many_uploads'); # OK

Whereas with a manual access to the hash table, you'll end up with one element
in @uploads, being the ARRAY ref:

    my @uploads = request->uploads->{'many_uploads'}; # $uploads[0]: ARRAY(0xXXXXX)

That is why this accessor should be used instead of a manual access to
C<uploads>.

=method cookies()

Returns a reference to a hash containing cookies, where the keys are the names of the
cookies and values are L<Dancer2::Core::Cookie> objects.

=cut











=head1 SEE ALSO

L<Dancer2>

=cut
