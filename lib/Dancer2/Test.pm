package Dancer2::Test;
# ABSTRACT: Useful routines for testing Dancer2 apps

use strict;
use warnings;

use Carp qw<carp croak>;
use Test::More;
use Test::Builder;
use URI::Escape;
use Data::Dumper;
use File::Temp;
use Ref::Util qw<is_arrayref>;

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

  is_pod_covered
  route_pod_coverage

);

#dancer1 also has read_logs, response_redirect_location_is
#cf. https://github.com/PerlDancer2/Dancer22/issues/25

use Dancer2::Core::Dispatcher;
use Dancer2::Core::Request;

# singleton to store all the apps
my $_dispatcher = Dancer2::Core::Dispatcher->new;

# prevent deprecation warnings
our $NO_WARN = 0;

# can be called with the ($method, $path, $option) triplet,
# or can be fed a request object directly, or can be fed
# a single string, assumed to be [ GET => $string ]
# or can be fed a response (which is passed through without
# any modification)
sub dancer_response {
    carp 'Dancer2::Test is deprecated, please use Plack::Test instead'
        unless $NO_WARN;

    _find_dancer_apps_for_dispatcher();

    # useful for the high-level tests
    return $_[0] if ref $_[0] eq 'Dancer2::Core::Response';

    my ( $request, $env ) =
      ref $_[0] eq 'Dancer2::Core::Request'
      ? _build_env_from_request(@_)
      : _build_request_from_env(@_);

    # override the set_request so it actually sets our request instead
    {
        ## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
        no warnings qw<redefine once>;
        *Dancer2::Core::App::set_request = sub {
            my $self = shift;
            $self->_set_request( $request );
            $_->set_request( $request ) for @{ $self->defined_engines };
        };
    }

    # since the response is a PSGI response
    # we create a Response object which was originally expected
    my $psgi_response = $_dispatcher->dispatch($env);
    return Dancer2::Core::Response->new(
        status  => $psgi_response->[0],
        headers => $psgi_response->[1],
        content => $psgi_response->[2][0],
    );
}



sub _build_request_from_env {

    # arguments can be passed as the triplet
    # or as a arrayref, or as a simple string
    my ( $method, $path, $options ) =
        @_ > 1 ? @_
      : is_arrayref($_[0]) ? @{ $_[0] }
      :                      ( GET => $_[0], {} );

    my $env = {
        %ENV,
        REQUEST_METHOD    => uc($method),
        PATH_INFO         => $path,
        QUERY_STRING      => '',
        'psgi.url_scheme' => 'http',
        SERVER_PROTOCOL   => 'HTTP/1.0',
        SERVER_NAME       => 'localhost',
        SERVER_PORT       => 3000,
        HTTP_HOST         => 'localhost',
        HTTP_USER_AGENT   => "Dancer2::Test simulator v " . Dancer2->VERSION,
    };

    if ( defined $options->{params} ) {
        my @params;
        while ( my ( $p, $value ) = each %{ $options->{params} } ) {
            if ( is_arrayref($value) ) {
                for my $v (@$value) {
                    push @params,
                      uri_escape_utf8($p) . '=' . uri_escape_utf8($v);
                }
            }
            else {
                push @params,
                  uri_escape_utf8($p) . '=' . uri_escape_utf8($value);
            }
        }
        $env->{QUERY_STRING} = join( '&', @params );
    }

    my $request = Dancer2::Core::Request->new( env => $env );

    # body
    $request->body( $options->{body} ) if exists $options->{body};

    # headers
    if ( $options->{headers} ) {
        for my $header ( @{ $options->{headers} } ) {
            my ( $name, $value ) = @{$header};
            $request->header( $name => $value );
            if ( $name =~ /^cookie$/i ) {
                $env->{HTTP_COOKIE} = $value;
            }
        }
    }

    # files
    if ( $options->{files} ) {
        for my $file ( @{ $options->{files} } ) {
            my $headers = $file->{headers};
            $headers->{'Content-Type'} ||= 'text/plain';

            my $temp = File::Temp->new();
            if ( $file->{data} ) {
                print $temp $file->{data};
                close($temp);
            }
            else {
                require File::Copy;
                File::Copy::copy( $file->{filename}, $temp );
            }

            my $upload = Dancer2::Core::Request::Upload->new(
                filename => $file->{filename},
                size     => -s $temp->filename,
                tempname => $temp->filename,
                headers  => $headers,
            );

            ## keep temp_fh in scope so it doesn't get deleted too early
            ## But will get deleted by the time the test is finished.
            $upload->{temp_fh} = $temp;

            $request->uploads->{ $file->{name} } = $upload;
        }
    }

    # content-type
    if ( $options->{content_type} ) {
        $request->content_type( $options->{content_type} );
    }

    return ( $request, $env );
}

sub _build_env_from_request {
    my ($request) = @_;

    my $env = {
        REQUEST_METHOD    => $request->method,
        PATH_INFO         => $request->path,
        QUERY_STRING      => '',
        'psgi.url_scheme' => 'http',
        SERVER_PROTOCOL   => 'HTTP/1.0',
        SERVER_NAME       => 'localhost',
        SERVER_PORT       => 3000,
        HTTP_HOST         => 'localhost',
        HTTP_USER_AGENT   => "Dancer2::Test simulator v" . Dancer2->VERSION,
    };

    # TODO
    if ( my $params = $request->{_query_params} ) {
        my @params;
        while ( my ( $p, $value ) = each %{$params} ) {
            if ( is_arrayref($value) ) {
                for my $v (@$value) {
                    push @params,
                      uri_escape_utf8($p) . '=' . uri_escape_utf8($v);
                }
            }
            else {
                push @params,
                  uri_escape_utf8($p) . '=' . uri_escape_utf8($value);
            }
        }
        $env->{QUERY_STRING} = join( '&', @params );
    }

    # TODO files

    return ( $request, $env );
}

sub response_status_is {
    my ( $req, $status, $test_name ) = @_;
    carp 'Dancer2::Test is deprecated, please use Plack::Test instead'
        unless $NO_WARN;

    $test_name ||= "response status is $status for " . _req_label($req);

    my $response = dancer_response($req);

    my $tb = Test::Builder->new;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $tb->is_eq( $response->[0], $status, $test_name );
}

sub _find_route_match {
    my ( $request, $env ) =
      ref $_[0] eq 'Dancer2::Core::Request'
      ? _build_env_from_request(@_)
      : _build_request_from_env(@_);

    for my $app (@{$_dispatcher->apps}) {
        for my $route (@{$app->routes->{lc($request->method)}}) {
            if ( $route->match($request) ) {
                return 1;
            }
        }
    }
    return 0;
}

sub route_exists {
    carp 'Dancer2::Test is deprecated, please use Plack::Test instead'
        unless $NO_WARN;

    my $tb = Test::Builder->new;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $tb->ok( _find_route_match($_[0]), $_[1]);
}

sub route_doesnt_exist {
    carp 'Dancer2::Test is deprecated, please use Plack::Test instead'
        unless $NO_WARN;

    my $tb = Test::Builder->new;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $tb->ok( !_find_route_match($_[0]), $_[1]);
}

sub response_status_isnt {
    my ( $req, $status, $test_name ) = @_;

    carp 'Dancer2::Test is deprecated, please use Plack::Test instead'
        unless $NO_WARN;

    $test_name ||= "response status is not $status for " . _req_label($req);

    my $response = dancer_response($req);

    my $tb = Test::Builder->new;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $tb->isnt_eq( $response->[0], $status, $test_name );
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
        my ( $req, $want, $test_name, $cmp ) = @_;

        if ( @_ == 3 ) {
            $cmp       = $test_name;
            $test_name = $cmp_name{$cmp};
            $test_name =
              "response content $test_name $want for " . _req_label($req);
        }

        my $response = dancer_response($req);

        my $tb = Test::Builder->new;
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        $tb->$cmp( $response->[2][0], $want, $test_name );
    }
}

sub response_content_is {
    carp 'Dancer2::Test is deprecated, please use Plack::Test instead'
        unless $NO_WARN;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    _cmp_response_content( @_, 'is_eq' );
}

sub response_content_isnt {
    carp 'Dancer2::Test is deprecated, please use Plack::Test instead'
        unless $NO_WARN;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    _cmp_response_content( @_, 'isnt_eq' );
}

sub response_content_like {
    carp 'Dancer2::Test is deprecated, please use Plack::Test instead'
        unless $NO_WARN;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    _cmp_response_content( @_, 'like' );
}

sub response_content_unlike {
    carp 'Dancer2::Test is deprecated, please use Plack::Test instead'
        unless $NO_WARN;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    _cmp_response_content( @_, 'unlike' );
}

sub response_content_is_deeply {
    my ( $req, $matcher, $test_name ) = @_;
    carp 'Dancer2::Test is deprecated, please use Plack::Test instead'
        unless $NO_WARN;
    $test_name ||= "response content looks good for " . _req_label($req);

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $response = _req_to_response($req);
    is_deeply $response->[2][0], $matcher, $test_name;
}

sub response_is_file {
    my ( $req, $test_name ) = @_;
    carp 'Dancer2::Test is deprecated, please use Plack::Test instead'
        unless $NO_WARN;
    $test_name ||= "a file is returned for " . _req_label($req);

    my $response = _get_file_response($req);
    my $tb       = Test::Builder->new;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return $tb->ok( defined($response), $test_name );
}

sub response_headers_are_deeply {
    my ( $req, $expected, $test_name ) = @_;
    carp 'Dancer2::Test is deprecated, please use Plack::Test instead'
        unless $NO_WARN;
    $test_name ||= "headers are as expected for " . _req_label($req);

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $response = dancer_response( _expand_req($req) );

    is_deeply(
        _sort_headers( $response->[1] ),
        _sort_headers($expected), $test_name
    );
}

sub response_headers_include {
    my ( $req, $expected, $test_name ) = @_;
    carp 'Dancer2::Test is deprecated, please use Plack::Test instead'
        unless $NO_WARN;
    $test_name ||= "headers include expected data for " . _req_label($req);
    my $tb = Test::Builder->new;

    my $response = dancer_response($req);
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    print STDERR "Headers are: "
      . Dumper( $response->[1] )
      . "\n Expected to find header: "
      . Dumper($expected)
      if !$tb->ok(
        _include_in_headers( $response->[1], $expected ),
        $test_name
      );
}

sub route_pod_coverage {

    require Pod::Simple::Search;
    require Pod::Simple::SimpleTree;

    my $all_routes = {};

    foreach my $app ( @{ $_dispatcher->apps } ) {
        my $routes           = $app->routes;
        my $available_routes = [];
        foreach my $method ( sort { $b cmp $a } keys %$routes ) {
            foreach my $r ( @{ $routes->{$method} } ) {

                # we don't need pod coverage for head
                next if $method eq 'head';
                push @$available_routes, $method . ' ' . $r->spec_route;
            }
        }
        ## copy dereferenced array
        $all_routes->{ $app->name }{routes} = [@$available_routes]
          if @$available_routes;

        # Pod::Simple v3.30 excluded the current directory even when in @INC.
        # include the current directory as a search path; its backwards compatible
        # with previous version.
        my $undocumented_routes = [];
        my $file                = Pod::Simple::Search->new->find( $app->name, '.' );
        if ($file) {
            $all_routes->{ $app->name }{has_pod} = 1;
            my $parser       = Pod::Simple::SimpleTree->new->parse_file($file);
            my $pod_dataref  = $parser->root;
            my $found_routes = {};
            for ( my $i = 0; $i < @$available_routes; $i++ ) {

                my $r          = $available_routes->[$i];
                my $app_string = lc $r;
                $app_string =~ s/\*/_REPLACED_STAR_/g;

                for ( my $idx = 0; $idx < @$pod_dataref; $idx++ ) {
                    my $pod_part = $pod_dataref->[$idx];

                    next if !is_arrayref($pod_part);
                    foreach my $ref_part (@$pod_part) {
                        is_arrayref($ref_part)
                            and push @$pod_dataref, $ref_part;
                    }

                    my $pod_string = lc $pod_part->[2];
                    $pod_string =~ s/['|"|\s]+/ /g;
                    $pod_string =~ s/\s$//g;
                    $pod_string =~ s/\*/_REPLACED_STAR_/g;
                    if ( $pod_string =~ m/^$app_string$/ ) {
                        $found_routes->{$app_string} = 1;
                        next;
                    }
                }
                if ( !$found_routes->{$app_string} ) {
                    push @$undocumented_routes, $r;
                }
            }
        }
        else {    ### no POD found
            $all_routes->{ $app->name }{has_pod} = 0;
        }
        if (@$undocumented_routes) {
            $all_routes->{ $app->name }{undocumented_routes} =
              $undocumented_routes;
        }
        elsif ( !$all_routes->{ $app->name }{has_pod}
            && @{ $all_routes->{ $app->name }{routes} } )
        {
            ## copy dereferenced array
            $all_routes->{ $app->name }{undocumented_routes} =
              [ @{ $all_routes->{ $app->name }{routes} } ];
        }
    }

    return $all_routes;
}

sub is_pod_covered {
    my ($test_name) = @_;

    $test_name ||= "is pod covered";
    my $route_pod_coverage = route_pod_coverage();

    my $tb = Test::Builder->new;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    foreach my $app ( @{ $_dispatcher->apps } ) {
        my %undocumented_route =
          ( map { $_ => 1 }
              @{ $route_pod_coverage->{ $app->name }{undocumented_routes} } );
        $tb->subtest(
            $app->name . $test_name,
            sub {
                foreach my $route (
                    @{ $route_pod_coverage->{ $app->name }{routes} } )
                {
                    ok( !$undocumented_route{$route}, "$route is documented" );
                }
            }
        );
    }
}

sub import {
    my ( $class, %options ) = @_;

    my @applications;
    if ( ref $options{apps} eq ref( [] ) ) {
        @applications = @{ $options{apps} };
    }
    else {
        my ( $caller, $script ) = caller;

        # if no app is passed, assume the caller is one.
        @applications = ($caller) if $caller->can('dancer_app');
    }

    # register the apps to the test dispatcher
    $_dispatcher->apps( [ map {
        $_->dancer_app->finish();
        $_->dancer_app;
    } @applications ] );

    $class->export_to_level( 1, $class, @EXPORT );
}

# private

sub _req_label {
    my $req = shift;

    return
        ref $req eq 'Dancer2::Core::Response' ? 'response object'
      : ref $req eq 'Dancer2::Core::Request'
      ? join( ' ', map { $req->$_ } qw/ method path / )
      : is_arrayref($req) ? join( ' ', @$req )
      :                     "GET $req";
}

sub _expand_req {
    my $req = shift;
    return is_arrayref($req) ? @$req : ( 'GET', $req );
}

# Sort arrayref of headers (turn it into a list of arrayrefs, sort by the header
# & value, then turn it back into an arrayref)
sub _sort_headers {
    my @originalheaders = @{ shift() };    # take a copy we can modify
    my @headerpairs;
    while ( my ( $header, $value ) = splice @originalheaders, 0, 2 ) {
        push @headerpairs, [ $header, $value ];
    }

    # We have an array of arrayrefs holding header => value pairs; sort them by
    # header then value, and return them flattened back into an arrayref
    return [
        map {@$_}
        sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } @headerpairs
    ];
}

# make sure the given header sublist is included in the full headers array
sub _include_in_headers {
    my ( $full_headers, $expected_subset ) = @_;

    # walk through all the expected header pairs, make sure
    # they exist with the same value in the full_headers list
    # return false as soon as one is not.
    for ( my $i = 0; $i < scalar(@$expected_subset); $i += 2 ) {
        my ( $name, $value ) =
          ( $expected_subset->[$i], $expected_subset->[ $i + 1 ] );
        return 0
          unless _check_header( $full_headers, $name, $value );
    }

    # we've found all the expected pairs in the $full_headers list
    return 1;
}

sub _check_header {
    my ( $headers, $key, $value ) = @_;
    for ( my $i = 0; $i < scalar(@$headers); $i += 2 ) {
        my ( $name, $val ) = ( $headers->[$i], $headers->[ $i + 1 ] );
        return 1 if $name eq $key && $value eq $val;
    }
    return 0;
}

sub _req_to_response {
    my $req = shift;

    # already a response object
    return $req if ref $req eq 'Dancer2::Core::Response';

    return dancer_response( is_arrayref($req) ? @$req : ( 'GET', $req ) );
}

# make sure we have at least one app in the dispatcher, and if not,
# we must have at this point an app within the caller
sub _find_dancer_apps_for_dispatcher {
    return if scalar( @{ $_dispatcher->apps } );

    for ( my $deep = 0; $deep < 5; $deep++ ) {
        my $caller = caller($deep);
        next if !$caller || !$caller->can('dancer_app');

        return $_dispatcher->apps( [ $caller->dancer_app ] );
    }

    croak "Unable to find a Dancer2 app, did you use Dancer2 in your test?";
}

1;

__END__

=head1 SYNOPSIS

    use Test::More;
    use Plack::Test;
    use HTTP::Request::Common; # install separately

    use YourDancerApp;

    my $app  = YourDancerApp->to_app;
    my $test = Plack::Test->create($app);

    my $res = $test->request( GET '/' );
    is( $res->code, 200, '[GET /] Request successful' );
    like( $res->content, qr/hello, world/, '[GET /] Correct content' );

    done_testing;

=head1 DESCRIPTION

B<DEPRECATED. This module and all the functions listed below are deprecated. Do
not use this module.> The routines provided by this module for testing Dancer2
apps are buggy and unnecessary. Instead, use the L<Plack::Test> module as shown
in the SYNOPSIS above and ignore the functions in this documentation. Consult
the L<Plack::Test> documentation for further details.

This module will be removed from the Dancer2 distribution in the near future.
You should migrate all tests that use it over to the L<Plack::Test> module and
remove this module from your system. This module will throw warnings to remind
you.

For now, you can silence the warnings by setting the C<NO_WARN> option:

    $Dancer::Test::NO_WARN = 1;

In the functions below, $test_name is always optional.

=func dancer_response ($method, $path, $params, $arg_env);

Returns a Dancer2::Core::Response object for the given request.

Only $method and $path are required.

$params is a hashref with 'body' as a string; 'headers' can be an arrayref or
a HTTP::Headers object, 'files' can be arrayref of hashref, containing some
files to upload:

    dancer_response($method, $path,
        {
            params => $params,
            body => $body,
            headers => $headers,
            files => [ { filename => '/path/to/file', name => 'my_file' } ],
        }
    );

A good reason to use this function is for testing POST requests. Since POST
requests may not be idempotent, it is necessary to capture the content and
status in one shot. Calling the response_status_is and response_content_is
functions in succession would make two requests, each of which could alter the
state of the application and cause Schrodinger's cat to die.

    my $response = dancer_response POST => '/widgets';
    is $response->status, 202, "response for POST /widgets is 202";
    is $response->content, "Widget #1 has been scheduled for creation",
        "response content looks good for first POST /widgets";

    $response = dancer_response POST => '/widgets';
    is $response->status, 202, "response for POST /widgets is 202";
    is $response->content, "Widget #2 has been scheduled for creation",
        "response content looks good for second POST /widgets";

It's possible to test file uploads:

    post '/upload' => sub { return upload('image')->content };

    $response = dancer_response(POST => '/upload', {files => [{name => 'image', filename => '/path/to/image.jpg'}]});

In addition, you can supply the file contents as the C<data> key:

    my $data  = 'A test string that will pretend to be file contents.';
    $response = dancer_response(POST => '/upload', {
        files => [{name => 'test', filename => "filename.ext", data => $data}]
    });

You can also supply a hashref of headers:

    headers => { 'Content-Type' => 'text/plain' }

=func response_status_is ($request, $expected, $test_name);

Asserts that Dancer2's response for the given request has a status equal to the
one given.

    response_status_is [GET => '/'], 200, "response for GET / is 200";

=func route_exists([$method, $path], $test_name)

Asserts that the given request matches a route handler in Dancer2's
registry. If the route would have returned a 404, the route still exists
and this test will pass.

Note that because Dancer2 uses the default route handler
L<Dancer2::Handler::File> to match files in the public folder when
no other route matches, this test will always pass.
You can disable the default route handlers in the configs but you probably
want L<Dancer2::Test/response_status_is> or L<Dancer2::Test/dancer_response>

    route_exists [GET => '/'], "GET / is handled";

=func route_doesnt_exist([$method, $path], $test_name)

Asserts that the given request does not match any route handler
in Dancer2's registry.

Note that this test is likely to always fail as any route not matched will
be handled by the default route handler in L<Dancer2::Handler::File>.
This can be disabled in the configs.

    route_doesnt_exist [GET => '/bogus_path'], "GET /bogus_path is not handled";

=func response_status_isnt([$method, $path], $status, $test_name)

Asserts that the status of Dancer2's response is not equal to the
one given.

    response_status_isnt [GET => '/'], 404, "response for GET / is not a 404";

=func response_content_is([$method, $path], $expected, $test_name)

Asserts that the response content is equal to the C<$expected> string.

 response_content_is [GET => '/'], "Hello, World",
        "got expected response content for GET /";

=func response_content_isnt([$method, $path], $not_expected, $test_name)

Asserts that the response content is not equal to the C<$not_expected> string.

    response_content_isnt [GET => '/'], "Hello, World",
        "got expected response content for GET /";

=func response_content_like([$method, $path], $regexp, $test_name)

Asserts that the response content for the given request matches the regexp
given.

    response_content_like [GET => '/'], qr/Hello, World/,
        "response content looks good for GET /";

=func response_content_unlike([$method, $path], $regexp, $test_name)

Asserts that the response content for the given request does not match the regexp
given.

    response_content_unlike [GET => '/'], qr/Page not found/,
        "response content looks good for GET /";

=func response_content_is_deeply([$method, $path], $expected_struct, $test_name)

Similar to response_content_is(), except that if response content and
$expected_struct are references, it does a deep comparison walking each data
structure to see if they are equivalent.

If the two structures are different, it will display the place where they start
differing.

    response_content_is_deeply [GET => '/complex_struct'],
        { foo => 42, bar => 24},
        "got expected response structure for GET /complex_struct";

=func response_is_file ($request, $test_name);

=func response_headers_are_deeply([$method, $path], $expected, $test_name)

Asserts that the response headers data structure equals the one given.

    response_headers_are_deeply [GET => '/'], [ 'X-Powered-By' => 'Dancer2 1.150' ];

=func response_headers_include([$method, $path], $expected, $test_name)

Asserts that the response headers data structure includes some of the defined ones.

    response_headers_include [GET => '/'], [ 'Content-Type' => 'text/plain' ];

=func route_pod_coverage()

Returns a structure describing pod coverage in your apps

for one app like this:

    package t::lib::TestPod;
    use Dancer2;

    =head1 NAME

    TestPod

    =head2 ROUTES

    =over

    =cut

    =item get "/in_testpod"

    testpod

    =cut

    get '/in_testpod' => sub {
        return 'get in_testpod';
    };

    get '/hello' => sub {
        return "hello world";
    };

    =item post '/in_testpod/*'

    post in_testpod

    =cut

    post '/in_testpod/*' => sub {
        return 'post in_testpod';
    };

    =back

    =head2 SPECIALS

    =head3 PUBLIC

    =over

    =item get "/me:id"

    =cut

    get "/me:id" => sub {
        return "ME";
    };

    =back

    =head3 PRIVAT

    =over

    =item post "/me:id"

    post /me:id

    =cut

    post "/me:id" => sub {
        return "ME";
    };

    =back

    =cut

    1;

route_pod_coverage;

would return something like:

    {
        't::lib::TestPod' => {
            'has_pod'             => 1,
            'routes'              => [
                "post /in_testpod/*",
                "post /me:id",
                "get /in_testpod",
                "get /hello",
                "get /me:id"
            ],
            'undocumented_routes' => [
                "get /hello"
            ]
        }
    }

=func is_pod_covered('is pod covered')

Asserts that your apps have pods for all routes

    is_pod_covered 'is pod covered'

to avoid test failures, you should document all your routes with one of the following:
head1, head2,head3,head4, item.

    ex:

    =item get '/login'

    route to login

    =cut

    if you use:

    any '/myaction' => sub {
        # code
    }

    or

    any ['get', 'post'] => '/myaction' => sub {
        # code
    };

    you need to create pods for each one of the routes created there.

=func import

When Dancer2::Test is imported, it should be passed all the
applications that are supposed to be tested.

If none passed, then the caller is supposed to be the sole application
to test.

    # t/sometest.t

    use t::lib::Foo;
    use t::lib::Bar;

    use Dancer2::Test apps => ['t::lib::Foo', 't::lib::Bar'];

=cut
