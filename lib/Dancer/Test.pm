package Dancer::Test;
use strict;
use warnings;

use Carp 'croak';
use Test::More;
use Test::Builder;
use URI::Escape;

use base 'Exporter';
our @EXPORT = qw(
    dancer_response
    response_content_is
    response_content_isnt
    response_status_is
    response_status_isnt
    response_headers_include
    response_headers_are_deeply
    response_content_like
    response_content_is_file
    response_content_is_deeply
);

use Dancer::Core::Dispatcher;
use Dancer::Core::Request;

my $_dispatcher = Dancer::Core::Dispatcher->new;

sub dancer_response {
    my $app = shift;
    my ($method, $path, $options) = @_;

    $_dispatcher->apps([ $app ]);

    my $env = {
        REQUEST_METHOD  => uc($method),
        PATH_INFO       => $path,
        QUERY_STRING    => '',
        'psgi.url_scheme' => 'http',
        SERVER_PROTOCOL => 'HTTP/1.0',
        SERVER_NAME     => 'localhost',
        SERVER_PORT     => 3000,
        HTTP_HOST       => 'localhost',
        HTTP_USER_AGENT => "Dancer::Test simulator v $Dancer::VERSION",
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

    # TODO body
    
    # headers
    if ($options->{headers}) {
        for my $header (@{ $options->{headers} }) {
            my ($name, $value) = @{$header};
            $request->header($name => $value);
        }
    }

    # TODO files

    # use Data::Dumper;
    # warn "Env created : ".Dumper($env);
    $_dispatcher->dispatch($env, $request)->to_psgi;
}

sub response_status_is {
    my $app = shift;
    my ($req, $status, $test_name) = @_;
    $test_name ||= "response status is $status for " . _req_label($req);

    my $response = _dancer_response($app, @$req);

    my $tb = Test::Builder->new;
    $tb->is_eq( $response->[0], $status, $test_name );
}

sub response_status_isnt {
    my $app = shift;
    my ($req, $status, $test_name) = @_;
    $test_name ||= "response status is not $status for " . _req_label($req);

    my $response = _dancer_response($app, @$req);

    my $tb = Test::Builder->new;
    $tb->isnt_eq( $response->[0], $status, $test_name );
}

sub response_content_is {
    my $app = shift;
    my ($req, $content, $test_name) = @_;
    $test_name ||= "response content is ok for " . _req_label($req);

    my $response = _dancer_response($app, @$req);

    my $tb = Test::Builder->new;
    $tb->is_eq( $response->[2][0], $content, $test_name );
}

sub response_content_isnt {
    my $app = shift;
    my ($req, $content, $test_name) = @_;
    $test_name ||= "response content is ok for " . _req_label($req);

    my $response = _dancer_response($app, @$req);

    my $tb = Test::Builder->new;
    $tb->isnt_eq( $response->[2][0], $content, $test_name );
}

sub response_content_like {
    my ($req, $matcher, $test_name) = @_;
    $test_name ||= "response content looks good for " . _req_label($req);

    my $response = _req_to_response($req);
    my $tb = Test::Builder->new;
    return $tb->like( $response->{content}, $matcher, $test_name );
}

sub response_content_is_deeply {
    my ($req, $matcher, $test_name) = @_;
    $test_name ||= "response content looks good for " . _req_label($req);

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $response = _req_to_response($req);
    is_deeply $response->{content}, $matcher, $test_name;
}

sub response_is_file {
    my ($req, $test_name) = @_;
    $test_name ||= "a file is returned for " . _req_label($req);

    my $response = _get_file_response($req);
    my $tb = Test::Builder->new;
    return $tb->ok(defined($response), $test_name);
}

sub response_headers_are_deeply {
    my $app = shift;
    my ($req, $expected, $test_name) = @_;
    $test_name ||= "headers are as expected for " . _req_label($req);

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $response = _dancer_response($app, _expand_req($req));
    
    is_deeply(
        _sort_headers( $response->[1] ),
        _sort_headers( $expected ),
        $test_name
    );
}

sub response_headers_include {
    my $app = shift;
    my ($req, $expected, $test_name) = @_;
    $test_name ||= "headers include expected data for @$req";
    my $tb = Test::Builder->new;

    my $response = _dancer_response($app, _expand_req($req));
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

1;
