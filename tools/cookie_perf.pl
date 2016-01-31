#!/usr/bin/env perl
use strict;
use warnings;

BEGIN {

    # Freeze time at Tue, 15-Jun-2010 00:00:00 GMT
    *CORE::GLOBAL::time = sub { return 1276560000 }
}

use Cookie::Baker     ();
use Cookie::Baker::XS ();
use HTTP::XSCookies   ();
use URI::Escape       ();
use Dumbbench;

my $request_cookie =
  'Last-Access=28-Jan-2016; CN=SomeString_here!98283747!8273646!0; CP=H2; GeoIP=MT:00:Valletta:35.90:14.51:v4; my-sessionId=928737ejd83jd9i';

my @cake = (
    {   name    => 'bar',
        value   => 'foo',
        expires => '+2h',
        secure  => 1
    },
    {   name      => 'bar',
        value     => 'foo',
        domain    => 'dancer.org',
        path      => '/dance',
        http_only => 1
    },
    {   name  => 'bar',
        value => 'foo',
    },
);

sub plack_crush {
    my %results;
    my @pairs = grep m/=/, split "[;,] ?", shift;
    for my $pair (@pairs) {
        $pair =~ s/^\s+//;
        $pair =~ s/\s+$//;
        my ($key, $value) = map URI::Escape::uri_unescape($_),
          split("=", $pair, 2);
        $results{$key} = $value unless exists $results{$key};
    }
    return \%results;
}

sub dancer_bake {
    my $href = shift;

    my $no_httponly = defined($href->{http_only}) && $href->{http_only} == 0;

    my @headers = $href->{name} . '=' . URI::Escape::uri_escape($href->{value});
    push @headers, "Path=" . $href->{path}       if $href->{path};
    push @headers, "Expires=" . $href->{expires} if $href->{expires};
    push @headers, "Domain=" . $href->{domain}   if $href->{domain};
    push @headers, "Secure"                      if $href->{secure};
    push @headers, 'HttpOnly' unless $no_httponly;

    return join '; ', @headers;
}

sub xscookies_bake {
    my $href = shift;
    return HTTP::XSCookies::bake_cookie(
        $href->{name},
        {   value    => $href->{value},
            path     => $href->{path},
            domain   => $href->{domain},
            expires  => $href->{expires},
            httponly => $href->{http_only},
            secure   => $href->{secure},
        }
    );
}

sub cookiebaker_bake {
    my $href = shift;
    return Cookie::Baker::bake_cookie(
        $href->{name},
        {   value    => $href->{value},
            path     => $href->{path},
            domain   => $href->{domain},
            expires  => $href->{expires},
            httponly => $href->{http_only},
            secure   => $href->{secure},
        }
    );
}

my $bench = Dumbbench->new(
    target_rel_precision => 0.005,
    initial_runs         => 20,
);

my $max = 100000;

$bench->add_instances(
    Dumbbench::Instance::PerlSub->new(
        name => 'crush Dancer2',
        code => sub {
            for (1 .. $max) {
                scalar plack_crush($request_cookie);
            }
        },
    ),

    Dumbbench::Instance::PerlSub->new(
        name => 'crush HTTP::XSCookies',
        code => sub {
            for (1 .. $max) {
                scalar HTTP::XSCookies::crush_cookie($request_cookie);
            }
        },
    ),

    Dumbbench::Instance::PerlSub->new(
        name => 'crush Cookie::Baker PP',
        code => sub {
            for (1 .. $max) {
                scalar Cookie::Baker::pp_crush_cookie($request_cookie);
            }
        },
    ),

    Dumbbench::Instance::PerlSub->new(
        name => 'crush Cookie::Baker::XS',
        code => sub {
            for (1 .. $max) {
                scalar Cookie::Baker::XS::crush_cookie($request_cookie);
            }
        },
    ),

    Dumbbench::Instance::PerlSub->new(
        name => 'bake Dancer2',
        code => sub {
            for (1 .. $max) {
                foreach (@cake) {
                    scalar dancer_bake($_);
                }
            }
        },
    ),

    Dumbbench::Instance::PerlSub->new(
        name => 'bake Cookie::Baker::XS',
        code => sub {
            for (1 .. $max) {
                foreach (@cake) {
                    scalar xscookies_bake($_);
                }
            }
        },
    ),

    Dumbbench::Instance::PerlSub->new(
        name => 'bake Cookie::Baker',
        code => sub {
            for (1 .. $max) {
                foreach (@cake) {
                    scalar cookiebaker_bake($_);
                }
            }
        },
    ),

);
$bench->run;
$bench->report;
