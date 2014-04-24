use strict;
use warnings;
use Test::More;

use YAML;
use Test::TCP 1.13;
use File::Temp 0.22;
use LWP::UserAgent;
use HTTP::Date qw/str2time/;
use File::Spec;

sub extract_cookie {
    my ($res) = @_;
    my @cookies = $res->header('set-cookie');
    for my $c (@cookies) {
        next unless $c =~ /dancer\.sid/;    # custom
        my @parts = split /;\s+/, $c;
        my %hash =
          map { my ( $k, $v ) = split /\s*=\s*/; $v ||= 1; ( lc($k), $v ) }
          @parts;
        $hash{expires} = str2time( $hash{expires} )
          if $hash{expires};
        return \%hash;
    }
    return;
}

my $tempdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );

for my $session_expires ( 3600, '1h', '1 hour' ) {
    Test::TCP::test_tcp(
        client => sub {
            my $port = shift;

            my $ua = LWP::UserAgent->new;
            $ua->cookie_jar( { file => "$tempdir/.cookies.txt" } );

            my ( $res, $cookie );

            # set value into session
            $res = $ua->get("http://127.0.0.1:$port/foo/set_session/larry");
            ok $res->is_success, "/foo/set_session/larry";
            $cookie = extract_cookie($res);
            my $err;
            ok $cookie, "session cookie set"
              or $err++;
            ok $cookie->{expires} - time > 3540,
              "cookie expiration is in future"
              or $err++;
            is $cookie->{domain}, '127.0.0.1', "cookie domain set"
              or $err++;
            is $cookie->{path}, '/foo', "cookie path set"
              or $err++;
            is $cookie->{httponly}, undef, "cookie has not set HttpOnly";
            diag explain $cookie
              if $err;

            # read value back
            $res = $ua->get("http://127.0.0.1:$port/foo/read_session");
            ok $res->is_success, "/foo/read_session";
            like $res->content, qr/name='larry'/, "session value looks good";

            File::Temp::cleanup();
        },
        server => sub {
            my $port = shift;

            use Dancer2;

            get '/has_session' => sub {
                return context->has_session;
            };

            get '/foo/set_session/*' => sub {
                my ($name) = splat;
                session name => $name;
            };

            get '/foo/read_session' => sub {
                my $name = session('name') || '';
                "name='$name'";
            };

            get '/foo/destroy_session' => sub {
                my $name = session('name') || '';
                context->destroy_session;
                return "destroyed='$name'";
            };

            setting appdir => $tempdir;
            setting(
                engines => {
                    session => {
                        Simple => {
                            cookie_name     => 'dancer.sid',
                            cookie_domain   => '127.0.0.1',
                            cookie_path     => '/foo',
                            cookie_duration => $session_expires,
##                    is_secure => 0, # can't easily test without https test server
                            is_http_only => 0,    # will not show up in cookie
                        },
                    },
                }
            );
            setting( session => 'Simple' );

            set(show_errors  => 1,
                startup_info => 0,
                environment  => 'production',
                port         => $port
            );

            # we're overiding a RO attribute only for this test!
            Dancer2->runner->{'port'} = $port;
            start;
        },
    );

}
done_testing;
