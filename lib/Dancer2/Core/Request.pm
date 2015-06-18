package Dancer2::Core::Request;
# ABSTRACT: Interface for accessing incoming requests

use strict;
use warnings;
use parent 'Plack::Request';

use Carp;
use Encode;
use HTTP::Body;
use URI;
use URI::Escape;
use Class::Load 'try_load_class';
use Safe::Isa;

use Dancer2::Core::Types;
use Dancer2::Core::Request::Upload;
use Dancer2::Core::Cookie;

# comes from Dancer2::Core::Role::Headers
# ("headers" attribute is available in Plack::Request already)
sub headers_to_array {
    my $self = shift;

    my $headers = [
        map {
            my $k = $_;
            map {
                my $v = $_;
                $v =~ s/^(.+)\r?\n(.*)$/$1\r\n $2/;
                ( $k => $v )
            } $self->headers->header($_);
          } $self->headers->header_field_names
    ];

    return $headers;
}

# add an attribute for each HTTP_* variables
# (HOST is managed manually)
my @http_env_keys = (qw/
    accept_charset
    accept_encoding
    accept_language
    connection
    keep_alive
    x_requested_with
/);

# apparently you can't eval core functions
sub accept { $_[0]->env->{'HTTP_ACCEPT'} }

eval << "_EVAL" for @http_env_keys; ## no critic
sub $_ { \$_[0]->env->{ 'HTTP_' . ( uc $_ ) } }
_EVAL

# check presence of XS module to speedup request
our $XS_URL_DECODE         = try_load_class('URL::Encode::XS');
our $XS_PARSE_QUERY_STRING = try_load_class('CGI::Deurl::XS');

our $_id = 0;

# self->new( env => {}, serializer => $s, is_behind_proxy => 0|1 )
sub new {
    my ( $class, @args ) = @_;

    # even sized list
    @args % 2 == 0
        or croak 'Must provide even sized list';

    my %opts = @args;
    my $env  = $opts{'env'};

    my $self = $class->SUPER::new($env);

    if ( my $s = $opts{'serializer'} ) {
        $s->$_does('Dancer2::Core::Role::Serializer')
            or croak 'Serializer provided not a Serializer object';

        $self->{'serializer'} = $s;
    }

    # additionally supported attributes
    $self->{'id'}              = ++$_id;
    $self->{'vars'}            = {};
    $self->{'is_behind_proxy'} = !!$opts{'is_behind_proxy'};

    $self->init;

    return $self;
}

# a buffer for per-request variables
sub vars { $_[0]->{'vars'} }

sub var {
    my $self = shift;
    @_ == 2
      ? $self->vars->{ $_[0] } = $_[1]
      : $self->vars->{ $_[0] };
}

# I don't like this. I know send_file uses this and I wonder
# if we can remove it.
#   -- Sawyer
sub set_path_info { $_[0]->env->{'PATH_INFO'} = $_[1] }

# XXX: incompatible with Plack::Request
sub body { $_[0]->{'body'} || '' }

sub id { $_id }

# Private 'read-only' attributes for request params. See the params()
# method for the public interface.
#
# _body_params, _query_params and _route_params have setter methods that
# decode byte string to characters before setting; If you know you have
# decoded (character) params, such as output from a deserializer, you can
# set these directly in the request object hash to avoid the decode op.
sub _params { $_[0]->{'_params'} ||= $_[0]->_build_params }

sub _has_params { defined $_[0]->{'_params'} }

sub _body_params { $_[0]->{'_body_params'} }

sub _set_body_params {
    my ( $self, $params ) = @_;
    $self->{_body_params} = _decode( $params );
    $self->_build_params();
}

sub _query_params { $_[0]->{'_query_params'} }

sub _set_query_params {
    my ( $self, $params ) = @_;
    $self->{_query_params} = _decode( $params );
    $self->_build_params();
}

sub _route_params { $_[0]->{'_route_params'} ||= {} }

sub _set_route_params {
    my ( $self, $params ) = @_;
    $self->{_route_params} = _decode( $params );
    $self->_build_params();
}

# XXX: incompatible with Plack::Request
sub uploads { $_[0]->{'uploads'} }

sub body_is_parsed { $_[0]->{'body_is_parsed'} || 0 }

sub is_behind_proxy { $_[0]->{'is_behind_proxy'} || 0 }

sub host {
    my ($self) = @_;

    if ( $self->is_behind_proxy and exists $self->env->{'HTTP_X_FORWARDED_HOST'} ) {
        my @hosts = split /\s*,\s*/, $self->env->{'HTTP_X_FORWARDED_HOST'}, 2;
        return $hosts[0];
    } else {
        return $self->env->{'HTTP_HOST'};
    }
}

# aliases, kept for backward compat
sub agent                 { shift->user_agent }
sub remote_address        { shift->address }
sub forwarded_for_address { shift->env->{'HTTP_X_FORWARDED_FOR'} }
sub forwarded_host        { shift->env->{'HTTP_X_FORWARDED_HOST'} }

# there are two options
sub forwarded_protocol    {
    $_[0]->env->{'HTTP_X_FORWARDED_PROTOCOL'} ||
    $_[0]->env->{'HTTP_X_FORWARDED_PROTO'}    ||
    $_[0]->env->{'HTTP_FORWARDED_PROTO'}
}

sub scheme {
    my ($self) = @_;
    my $scheme = $self->is_behind_proxy
               ? $self->forwarded_protocol
               : '';

    return $scheme || $self->env->{'psgi.url_scheme'};
}

sub serializer { $_[0]->{'serializer'} }

sub data { $_[0]->{'data'} ||= &deserialize }

sub deserialize {
    my $self = shift;

    my $serializer = $self->serializer
        or return;

    # The latest draft of the RFC does not forbid DELETE to have content,
    # rather the behaviour is undefined. Take the most lenient route and
    # deserialize any content on delete as well.
    return
      unless grep { $self->method eq $_ } qw/ PUT POST PATCH DELETE /;

    # try to deserialize
    my $body = $self->_read_to_end();

    $body && length $body > 0
        or return;

    my $data = $serializer->deserialize($self->body);
    return if !defined $data;

    # Set _body_params directly rather than using the setter. Deserializiation
    # returns characters and skipping the decode op in the setter ensures
    # that numerical data "stays" numerical; decoding an SV that is an IV
    # converts that to a PVIV. Some serializers are picky (JSON)..
    $self->{_body_params} = $data;
    $self->_build_params();

    return $data;
}

sub uri       { $_[0]->request_uri }
sub is_head   { $_[0]->method eq 'HEAD' }
sub is_post   { $_[0]->method eq 'POST' }
sub is_get    { $_[0]->method eq 'GET' }
sub is_put    { $_[0]->method eq 'PUT' }
sub is_delete { $_[0]->method eq 'DELETE' }
sub is_patch  { $_[0]->method eq 'PATCH' }

# public interface compat with CGI.pm objects
sub request_method { $_[0]->method }
sub input_handle { $_[0]->env->{'psgi.input'} }

sub init {
    my ($self) = @_;

    $self->{_chunk_size}    = 4096;
    $self->{_read_position} = 0;

    $self->{_http_body} =
      HTTP::Body->new( $self->content_type || '', $self->content_length );
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

    $part ||= '';
    my $uri = $self->base;

    # Make sure there's exactly one slash between the base and the new part
    my $base = $uri->path;
    $base =~ s|/$||;
    $part =~ s|^/||;
    $uri->path("$base/$part");

    $uri->query_form($params) if $params;

    return $dont_escape
           ? uri_unescape( ${ $uri->canonical } )
           : ${ $uri->canonical };
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

# XXX: incompatible with Plack::Request
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

# XXX incompatible with Plack::Request
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

    if ( $content_length && $content_length > 0 ) {
        while ( my $buffer = $self->_read() ) {
            $self->{body} .= $buffer;
        }
        $self->{_http_body}->add( $self->{body} );
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

# XXX: incompatible with Plack::Request
sub cookies { $_[0]->{'cookies'} ||= $_[0]->_build_cookies }

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
        if ( defined $value and $value ne '' ) {
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

An object representing a Dancer2 request. It aims to provide a proper
interface to anything you might need from a web request.

=head1 SYNOPSIS

In a route handler, the current request object can be accessed by the
C<request> keyword:

    get '/foo' => sub {
        request->params; # request, params parsed as a hash ref
        request->body;   # returns the request body, unparsed
        request->path;   # the path requested by the client
        # ...
    };

=head1 Common HTTP request headers

Commonly used client-supplied HTTP request headers are available through
specific accessors:

=over 4

=item C<accept>

HTTP header: C<HTTP_ACCEPT>.

=item C<accept_charset>

HTTP header: C<HTTP_ACCEPT_CHARSET>.

=item C<accept_encoding>

HTTP header: C<HTTP_ACCEPT_ENCODING>.

=item C<accept_language>

HTTP header: C<HTTP_ACCEPT_LANGUAGE>.

=item C<agent>

Alias for C<user_agent>) below.

=item C<connection>

HTTP header: C<HTTP_CONNECTION>.

=item C<content_encoding>

HTTP header: C<HTTP_CONTENT_ENCODING>.

=item C<content_length>

HTTP header: C<HTTP_CONTENT_LENGTH>.

=item C<content_type>

HTTP header: C<HTTP_CONTENT_TYPE>.

=item C<forwarded_for_address>

HTTP header: C<HTTP_X_FORWARDED_FOR>.

=item C<forwarded_host>

HTTP header: C<HTTP_X_FORWARDED_HOST>.

=item C<forwarded_protocol>

One of either C<HTTP_X_FORWARDED_PROTOCOL>, C<HTTP_X_FORWARDED_PROTO>, or
C<HTTP_FORWARDED_PROTO>.

=item C<host>

Checks whether we are behind a proxy using the C<is_behind_proxy>
configuration option, and if so returns the first
C<HTTP_X_FORWARDED_HOST>, since this is a comma seperated list.

If you have not configured that you behind a proxy, it returns HTTP
header C<HTTP_HOST>.

=item C<keep_alive>

HTTP header: C<HTTP_KEEP_ALIVE>.

=item C<referer>

HTTP header: C<HTTP_REFERER>.

=item C<user_agent>

HTTP header: C<HTTP_USER_AGENT>.

=item C<x_requested_with>

HTTP header: C<HTTP_X_REQUESTED_WITH>.

=back

=method address

Return the IP address of the client.

=method base

Returns an absolute URI for the base of the application.  Returns a L<URI>
object (which stringifies to the URL, as you'd expect).

=method body_parameters

Returns a L<Hash::MultiValue> object representing the POST parameters.

=method body

Return the raw body of the request, unparsed.

If you need to access the body of the request, you have to use this accessor and
should not try to read C<psgi.input> by hand. C<Dancer2::Core::Request>
already did it for you and kept the raw body untouched in there.

=method content

Returns the undecoded byte string POST body.

=method cookies

Returns a reference to a hash containing cookies, where the keys are the names of the
cookies and values are L<Dancer2::Core::Cookie> objects.

=method data

If the application has a serializer and if the request has serialized
content, returns the deserialized structure as a hashref.

=method dispatch_path

The part of the C<path> after C<base>. This is the path used
for dispatching the request to routes.

=method env

Return the current PSGI environment hash reference.

=method header($name)

Return the value of the given header, if present. If the header has multiple
values, returns an the list of values if called in list context, the first one
in scalar.

=method headers

Returns an L<HTTP::Headers> object representing the headers.

=method id

The ID of the request. This allows you to trace a specific request in loggers,
per the string created using C<to_string>.

The ID of the request is essentially the number of requests run in the current
class.

=method input

Alias to C<input_handle> method below.

=method input_handle

Alias to the PSGI input handle (C<< <request->env->{psgi.input}> >>)

=method is_ajax

Return true if the value of the header C<X-Requested-With> is
C<XMLHttpRequest>.

=method is_delete

Return true if the method requested by the client is 'DELETE'

=method is_get

Return true if the method requested by the client is 'GET'

=method is_head

Return true if the method requested by the client is 'HEAD'

=method is_post

Return true if the method requested by the client is 'POST'

=method is_put

Return true if the method requested by the client is 'PUT'

=method logger

Returns the C<psgix.logger> code reference, if exists.

=method method

Return the HTTP method used by the client to access the application.

While this method returns the method string as provided by the environment, it's
better to use one of the following boolean accessors if you want to inspect the
requested method.

=method new

The constructor of the class, used internally by Dancer2's core to create request
objects.

It uses the environment hash table given to build the request object:

    Dancer2::Core::Request->new( env => $env );

Two additional parameters for instantiation are C<body_is_parsed> boolean
(indicating if the request should avoid parsing the body again), and
C<serializer> which can provide a serializer object to work with when
reading the request body.

=method param($key)

Calls the C<params> method below and fetches the key provided.

=method params($source)

Called in scalar context, returns a hashref of params, either from the specified
source (see below for more info on that) or merging all sources.

So, you can use, for instance:

    my $foo = params->{foo}

If called in list context, returns a list of key and value pairs, so you could use:

    my %allparams = params;

=method parameters

Returns a L<Hash::MultiValue> object with merged GET and POST parameters.

=method path

The path requested by the client, normalized. This is effectively
C<path_info> or a single forward C</>.

=method path_info

The raw requested path. This could be empty. Use C<path> instead.

=method port

Return the port of the server.

=method protocol

Return the protocol (I<HTTP/1.0> or I<HTTP/1.1>) used for the request.

=method query_parameters

Returns a L<Hash::MultiValue> parameters object.

=method query_string

Returns the portion of the request defining the query itself - this is
what comes after the C<?> in a URI.

=method raw_body

Alias to C<content> method.

=method remote_address

Alias for C<address> method.

=method remote_host

Return the remote host of the client. This only works with web servers configured
to do a reverse DNS lookup on the client's IP address.

=method request_method

Alias to the C<method> accessor, for backward-compatibility with C<CGI> interface.

=method request_uri

Return the raw, undecoded request URI path.

=method scheme

Return the scheme of the request

=method script_name

Return script_name from the environment.

=method secure

Return true or false, indicating whether the connection is secure - this is
effectively checking if the scheme is I<HTTPS> or not.

=method serializer

Returns the optional serializer object used to deserialize request parameters.

=method session

Returns the C<psgix.session> hash, if exists.

=method session_options

Returns the C<psgix.session.options> hash, if exists.

=method to_string

Return a string representing the request object (e.g., C<GET /some/path>).

=method upload($name)

Context-aware accessor for uploads. It's a wrapper around an access to the hash
table provided by C<uploads()>. It looks at the calling context and returns a
corresponding value.

If you have many file uploads under the same name, and call C<upload('name')> in
an array context, the accessor will unroll the ARRAY ref for you:

    my @uploads = request->upload('many_uploads'); # OK

Whereas with a manual access to the hash table, you'll end up with one element
in C<@uploads>, being the arrayref:

    my @uploads = request->uploads->{'many_uploads'};
    # $uploads[0]: ARRAY(0xXXXXX)

That is why this accessor should be used instead of a manual access to
C<uploads>.

=method uploads

Returns a reference to a hash containing uploads. Values can be either a
L<Dancer2::Core::Request::Upload> object, or an arrayref of
L<Dancer2::Core::Request::Upload>
objects.

You should probably use the C<upload($name)> accessor instead of manually accessing the
C<uploads> hash table.

=method uri

An alias to C<request_uri>.

=method uri_base

Same thing as C<base> above, except it removes the last trailing slash in the
path if it is the only path.

This means that if your base is I<http://myserver/>, C<uri_base> will return
I<http://myserver> (notice no trailing slash). This is considered very useful
when using templates to do the following thing:

    <link rel="stylesheet" href="[% request.uri_base %]/css/style.css" />

=method uri_for(path, params)

Constructs a URI from the base and the passed path. If params (hashref) is
supplied, these are added to the query string of the URI.

Thus, with the following base:

    http://localhost:5000/foo

You get the following behavior:

    my $uri = request->uri_for('/bar', { baz => 'baz' });
    print $uri; # http://localhost:5000/foo/bar?baz=baz

C<uri_for> returns a L<URI> object (which can stringify to the value).

=method user

Return remote user if defined.

=method var

By-name interface to variables stored in this request object.

  my $stored = $request->var('some_variable');

returns the value of 'some_variable', while

  $request->var('some_variable' => 'value');

will set it.

=method vars

Access to the internal hash of variables:

    my $value = $request->vars->{'my_key'};

You want to use C<var> above.

=head1 Fetching only params from a given source

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

=head1 EXTRA SPEED

If L<Dancer2::Core::Request> detects the following modules as installed,
it will use them to speed things up:

=over 4

=item * L<URL::Encode::XS>

=item * L<CGI::Deurl::XS>

=back
