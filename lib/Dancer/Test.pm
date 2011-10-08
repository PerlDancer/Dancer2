package Dancer::Test;
use strict;
use warnings;

use Carp 'croak';
use Test::Builder;
use URI::Escape;

use base 'Exporter';
our @EXPORT = qw(
    dancer_response
    response_content_is
    response_content_isnt
    response_status_is
    response_status_isnt
);

use Dancer::Core::Dispatcher;

my $_dispatcher = Dancer::Core::Dispatcher->new;

sub dancer_response {
    my $app = shift;
    my ($method, $path, $options) = @_;

    $_dispatcher->apps([ $app ]);

    my $env = {
        REQUEST_METHOD  => uc($method),
        PATH_INFO       => $path,
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

    # TODO body
    # TODO headers
    # TODO files

    # use Data::Dumper;
    # warn "Env created : ".Dumper($env);
    $_dispatcher->dispatch($env);
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

# private

# all the symbols exported by Dancer::Test are compiled so they can receive the
# $app object of the caller as their first argument.
sub import {
    my ($class, @args) = @_;
    my ($caller, $script) = caller;

    if (! $caller->can('dancer_app')) {
        croak "No dancer application for $caller "
            . "(Dancer::Test must be imported after the application)";
    }
    my $app = $caller->dancer_app;

    for my $symbol (@EXPORT) {
        my $orig_sub = _get_orig_symbol($symbol);
        my $new_sub = sub { $orig_sub->($app, @_) };
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

1;
