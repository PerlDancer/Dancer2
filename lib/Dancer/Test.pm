# ABSTRACT: Useful routines for testing Dancer apps

package Dancer::Test;
use strict;
use warnings;

use Carp 'croak';
use Test::More;
use Test::Builder;
use URI::Escape;

use parent 'Exporter';
our @EXPORT = qw(
    dancer_response

    response_content_is
    response_content_isnt
    response_content_is_deeply
    response_content_like
    response_content_unlike

    response_status_is
    response_status_isnt

    response_headers_include
    response_headers_are_deeply

    response_is_file

    route_exists
    route_doesnt_exist

);

#dancer1 also has read_logs, response_redirect_location_is
#cf. https://github.com/PerlDancer/Dancer2/issues/25

use Dancer::Core::Dispatcher;
use Dancer::Core::Request;

=head1 DESCRIPTION

provides useful routines to test Dancer apps.

$test_name is always optional.

=cut

my $_dispatcher = Dancer::Core::Dispatcher->new;

=func dancer_response ($method, $path, $params, $arg_env);

Returns a Dancer::Response object for the given request.

Only $method and $path are required.

$params is a hashref with 'body' as a string; 'headers' can be an arrayref or
a HTTP::Headers object, 'files' can be arrayref of hashref, containing some 
files to upload:

	dancer_response($method, $path, 
		{ params => $params, 
			body => $body, 
			headers => $headers, 
			files => [{filename => '/path/to/file', name => 'my_file'}] 
		}
	);

A good reason to use this function is for testing POST requests. Since POST
requests may not be idempotent, it is necessary to capture the content and
status in one shot. Calling the response_status_is and response_content_is
functions in succession would make two requests, each of which could alter the
state of the application and cause Schrodinger's cat to die.

    my $response = dancer_response POST => '/widgets';
    is $response->{status}, 202, "response for POST /widgets is 202";
    is $response->{content}, "Widget #1 has been scheduled for creation",
        "response content looks good for first POST /widgets";

    $response = dancer_response POST => '/widgets';
    is $response->{status}, 202, "response for POST /widgets is 202";
    is $response->{content}, "Widget #2 has been scheduled for creation",
        "response content looks good for second POST /widgets";

It's possible to test file uploads:

    post '/upload' => sub { return upload('image')->content };

    $response = dancer_response(POST => '/upload', {files => [{name => 'image', filename => '/path/to/image.jpg'}]});

In addition, you can supply the file contents as the C<data> key:

    my $data  = 'A test string that will pretend to be file contents.';
    $response = dancer_response(POST => '/upload', {
        files => [{name => 'test', filename => "filename.ext", data => $data}]
    });

=cut

# can be called with the ($method, $path, $option) triplet,
# or can be fed a request object directly, or can be fed
# a single string, assumed to be [ GET => $string ]
# or can be fed a response (which is passed through without
# any modification)
sub dancer_response {
    my $app = shift;
    $_dispatcher->apps([ $app ]);

    # useful for the high-level tests
    return $_[0] if ref $_[0] eq 'Dancer::Core::Response';

    my ( $request, $env ) = ref $_[0] eq 'Dancer::Core::Request'
        ? _build_env_from_request( @_ )
        : _build_request_from_env( @_ )
        ;

    return $_dispatcher->dispatch($env, $request);
}

sub _build_request_from_env {
    # arguments can be passed as the triplet
    # or as a arrayref, or as a simple string
    my ( $method, $path, $options ) 
        = @_ > 1               ? @_
        : ref $_[0] eq 'ARRAY' ? @{$_[0]}
        :                        ( GET => $_[0], {} )
        ;

    my $env = {
        REQUEST_METHOD  => uc($method),
        PATH_INFO       => $path,
        QUERY_STRING    => '',
        'psgi.url_scheme' => 'http',
        SERVER_PROTOCOL => 'HTTP/1.0',
        SERVER_NAME     => 'localhost',
        SERVER_PORT     => 3000,
        HTTP_HOST       => 'localhost',
        HTTP_USER_AGENT => "Dancer::Test simulator v ".Dancer->VERSION,
    };

    if (defined $options->{params}) {
        my @params;
        foreach my $p (keys %{$options->{params}}) {
           push @params,
             uri_escape($p).'='.uri_escape($options->{params}->{$p});
        }
        $env->{REQUEST_URI} = join('&', @params);
    }

    my $request = Dancer::Core::Request->new(env => $env);

    # body
    $request->body( $options->{body} ) if exists $options->{body};
    
    # headers
    if ($options->{headers}) {
        for my $header (@{ $options->{headers} }) {
            my ($name, $value) = @{$header};
            $request->header($name => $value);
        }
    }

    # TODO files
    
   return ( $request, $env );
}

sub _build_env_from_request {
    my ( $request ) = @_;

    my $env = {
        REQUEST_METHOD  => $request->method,
        PATH_INFO       => $request->path,
        QUERY_STRING    => '',
        'psgi.url_scheme' => 'http',
        SERVER_PROTOCOL => 'HTTP/1.0',
        SERVER_NAME     => 'localhost',
        SERVER_PORT     => 3000,
        HTTP_HOST       => 'localhost',
        HTTP_USER_AGENT => "Dancer::Test simulator v $Dancer::VERSION",
    };

    # TODO
    if (my $params = $request->{_query_params}) {
        my @params;
        foreach my $p (keys %{$params}) {
           push @params,
             uri_escape($p).'='.uri_escape($params->{$p});
        }
        $env->{REQUEST_URI} = join('&', @params);
    }

    # TODO files
    
   return ( $request, $env );
}

=func response_status_is ($request, $expected, $test_name);

Asserts that Dancer's response for the given request has a status equal to the
one given.

    response_status_is [GET => '/'], 200, "response for GET / is 200";

=cut

sub response_status_is {
    my $app = shift;
    my ($req, $status, $test_name) = @_;

    $test_name ||= "response status is $status for " . _req_label($req);

    my $response = _dancer_response($app, $req);

    my $tb = Test::Builder->new;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $tb->is_eq( $response->status, $status, $test_name );
}

=func route_exists([$method, $path], $test_name)

Asserts that the given request matches a route handler in Dancer's
registry.

    route_exists [GET => '/'], "GET / is handled";
=cut 

sub route_exists {
    my $app = shift;
    my ($req, $test_name) = @_;
    $test_name ||= "route exists for " . _req_label($req);
    response_status_is($req, 200, $test_name);
}

=func route_doesnt_exist([$method, $path], $test_name)

Asserts that the given request does not match any route handler 
in Dancer's registry.

    route_doesnt_exist [GET => '/bogus_path'], "GET /bogus_path is not handled";
    
=cut

sub route_doesnt_exist {
    my $app = shift;
    my ($req, $test_name) = @_;
    $test_name ||= "route doesn't exist for " . _req_label($req);
    
    response_status_is($req, 404, $test_name);
}

=func response_status_isnt([$method, $path], $status, $test_name)

Asserts that the status of Dancer's response is not equal to the
one given.

    response_status_isnt [GET => '/'], 404, "response for GET / is not a 404";
=cut

sub response_status_isnt {
    my $app = shift;
    my ($req, $status, $test_name) = @_;
    $test_name ||= "response status is not $status for " . _req_label($req);

    my $response = _dancer_response($app, $req);

    my $tb = Test::Builder->new;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $tb->isnt_eq( $response->status, $status, $test_name );
}

{
    # Map comparison operator names to human-friendly ones
    my %cmp_name = (
        is_eq   => "is",
        isnt_eq => "is not",
        like    => "matches",
        unlike  => "doesn't match",
    );

    sub _cmp_response_content {
        my $app = shift;
        my ($req, $want, $test_name, $cmp) = @_;

        if (@_ == 3) {
            $cmp = $test_name;
            $test_name = $cmp_name{$cmp};
        }

        $test_name ||= "response content $test_name $want for " . _req_label($req);
        my $response = _dancer_response($app, $req);
        
        my $tb = Test::Builder->new;
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        $tb->$cmp( $response->content, $want, $test_name );
    }
}

=func response_content_is([$method, $path], $expected, $test_name)

Asserts that the response content is equal to the C<$expected> string.

 response_content_is [GET => '/'], "Hello, World", 
        "got expected response content for GET /";
        
=cut

sub response_content_is {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    _cmp_response_content(@_, 'is_eq');
}

=func response_content_isnt([$method, $path], $not_expected, $test_name)

Asserts that the response content is not equal to the C<$not_expected> string.

    response_content_isnt [GET => '/'], "Hello, World", 
        "got expected response content for GET /";


=cut

sub response_content_isnt {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    _cmp_response_content(@_, 'isnt_eq');
}

=func response_content_like([$method, $path], $regexp, $test_name)

Asserts that the response content for the given request matches the regexp
given.

    response_content_like [GET => '/'], qr/Hello, World/, 
        "response content looks good for GET /";


=cut

sub response_content_like {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    _cmp_response_content(@_, 'like');
}

=func response_content_unlike([$method, $path], $regexp, $test_name)

Asserts that the response content for the given request does not match the regexp
given.

    response_content_unlike [GET => '/'], qr/Page not found/, 
        "response content looks good for GET /";

=cut

sub response_content_unlike {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    _cmp_response_content(@_, 'unlike');
}

=func response_content_is_deeply([$method, $path], $expected_struct, $test_name)

Similar to response_content_is(), except that if response content and 
$expected_struct are references, it does a deep comparison walking each data 
structure to see if they are equivalent.  

If the two structures are different, it will display the place where they start
differing.

    response_content_is_deeply [GET => '/complex_struct'], 
        { foo => 42, bar => 24}, 
        "got expected response structure for GET /complex_struct";

=cut

sub response_content_is_deeply {
    my ($req, $matcher, $test_name) = @_;
    $test_name ||= "response content looks good for " . _req_label($req);

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $response = _req_to_response($req);
    is_deeply $response->[2][0], $matcher, $test_name;
}

=func response_is_file ($request, $test_name);

=cut

sub response_is_file {
    my ($req, $test_name) = @_;
    $test_name ||= "a file is returned for " . _req_label($req);

    my $response = _get_file_response($req);
    my $tb = Test::Builder->new;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return $tb->ok(defined($response), $test_name);
}

=func response_headers_are_deeply([$method, $path], $expected, $test_name)

Asserts that the response headers data structure equals the one given.

    response_headers_are_deeply [GET => '/'], [ 'X-Powered-By' => 'Dancer 1.150' ];

=cut

sub response_headers_are_deeply {
    my $app = shift;
    my ($req, $expected, $test_name) = @_;
    $test_name ||= "headers are as expected for " . _req_label($req);

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $response = _dancer_response($app, _expand_req($req));

    is_deeply(
        _sort_headers( $response->headers_to_array ),
        _sort_headers( $expected ),
        $test_name
    );
}

=func response_headers_include([$method, $path], $expected, $test_name)

Asserts that the response headers data structure includes some of the defined ones.

    response_headers_include [GET => '/'], [ 'Content-Type' => 'text/plain' ];

=cut

sub response_headers_include {
    my $app = shift;
    my ($req, $expected, $test_name) = @_;
    $test_name ||= "headers include expected data for " . _req_label($req);
    my $tb = Test::Builder->new;

    my $response = _dancer_response($app, $req);
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return $tb->ok(_include_in_headers($response->headers_to_array, $expected), $test_name);
}


# private

# all the symbols exported by Dancer::Test are compiled so they can receive the
# $app object of the caller as their first argument.

sub import {
    my ($class, $app_name) = @_;
    my ($caller, $script) = caller;

    my $app;
    $app = $app_name->dancer_app
        if defined $app_name;

    if (! defined $app) {
        $caller->can('dancer_app') and
        $app = $caller->dancer_app;
    }

    for my $symbol (@EXPORT) {
        my $orig_sub = _get_orig_symbol($symbol);
        my $new_sub = sub {
            if (! defined $app) {
                my $c = caller;
                $app = $c->dancer_app;
            }
            $orig_sub->($app, @_)
        };
        {
            no strict 'refs';
            no warnings 'redefine';
            *{"Dancer::Test::$symbol"} = $new_sub;
        }
    }

    $class->export_to_level(1, $class, @EXPORT);
}

my $_orig_dsl_symbols = {};
sub _get_orig_symbol {
    my ($symbol) = @_;

    # already saved this one, return it
    return $_orig_dsl_symbols->{$symbol}
        if exists $_orig_dsl_symbols->{$symbol};

    # first time, save the symbol
    my $orig;
    {
        no strict 'refs';
        $orig = *{"Dancer::Test::${symbol}"}{CODE};

        # also bind the original symbol to a private name
        # in order to be able to call it manually from within Dancer.pm
        *{"Dancer::Test::_${symbol}"} = $orig;
    }

    # return the newborn cache version
    return $_orig_dsl_symbols->{$symbol} = $orig;
}

sub _req_label {
    my $req = shift;

    return ref $req eq 'Dancer::Core::Response' ? 'response object'
         : ref $req eq 'Dancer::Core::Request'  
                ? join( ' ', map { $req->$_ } qw/ method path / )
         : ref $req eq 'ARRAY' ? join( ' ', @$req )
         : "GET $req"
         ;
}

sub _expand_req {
    my $req = shift;
    return ref $req eq 'ARRAY' ? @$req : ( 'GET', $req );
}

# Sort arrayref of headers (turn it into a list of arrayrefs, sort by the header
# & value, then turn it back into an arrayref)
sub _sort_headers {
    my @originalheaders = @{ shift() }; # take a copy we can modify
    my @headerpairs;
    while (my ($header, $value) = splice @originalheaders, 0, 2) {
        push @headerpairs, [ $header, $value ];
    }

    # We have an array of arrayrefs holding header => value pairs; sort them by
    # header then value, and return them flattened back into an arrayref
    return [
        map  { @$_ }
        sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] }
        @headerpairs
    ];
}

# make sure the given header sublist is included in the full headers array
sub _include_in_headers {
    my ($full_headers, $expected_subset) = @_;

    # walk through all the expected header pairs, make sure
    # they exist with the same value in the full_headers list
    # return false as soon as one is not.
    for (my $i=0; $i<scalar(@$expected_subset); $i+=2) {
        my ($name, $value) = ($expected_subset->[$i], $expected_subset->[$i + 1]);
        return 0
          unless _check_header($full_headers, $name, $value);
    }

    # we've found all the expected pairs in the $full_headers list
    return 1;
}

sub _check_header {
    my ($headers, $key, $value) = @_;
    for (my $i=0; $i<scalar(@$headers); $i+=2) {
        my ($name, $val) = ($headers->[$i], $headers->[$i + 1]);
        return 1 if $name eq $key && $value eq $val;
    }
    return 0;
}

sub _req_to_response {
    my $req = shift;

    # already a response object
    return $req if ref $req eq 'Dancer::Core::Response';

    return dancer_response( ref $req eq 'ARRAY' ? @$req : ( 'GET', $req ) );
}

1;
