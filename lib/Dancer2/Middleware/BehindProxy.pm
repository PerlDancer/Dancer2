package Dancer2::Middleware::BehindProxy;
# ABSTRACT: Support Dancer2 apps when operating behing a reverse proxy

use warnings;
use strict;

use parent 'Plack::Middleware';
use Plack::Middleware::ReverseProxy;
use Plack::Middleware::ReverseProxyPath;

sub call {
    my($self, $env) = @_;

    # Plack::Middleware::ReverseProxy only supports
    # HTTP_X_FORWARDED_PROTO whereas Dancer2 also supports
    # HTTP_X_FORWARDED_PROTOCOL and HTTP_FORWARDED_PROTO
    for my $header (qw/HTTP_X_FORWARDED_PROTOCOL HTTP_FORWARDED_PROTO/) {
        if ( ! $env->{HTTP_X_FORWARDED_PROTO}
             && $env->{$header} )
        {
            $env->{HTTP_X_FORWARDED_PROTO} = $env->{$header};
            last;
        }
    }

    # Pr#503 added support for HTTP_X_FORWARDED_HOST containing multiple
    # values. Plack::Middleware::ReverseProxy takes the last (most recent)
    # whereas that #503 takes the first.
    if ( $env->{HTTP_X_FORWARDED_HOST} ) {
        my @hosts = split /\s*,\s*/, $env->{HTTP_X_FORWARDED_HOST}, 2;
        $env->{HTTP_X_FORWARDED_HOST} = $hosts[0];
    }

    # Plack::Middleware::ReverseProxyPath uses X-Forwarded-Script-Name
    # whereas Dancer previously supported HTTP_REQUEST_BASE
    if ( ! $env->{HTTP_X_FORWARDED_SCRIPT_NAME}
         && $env->{HTTP_REQUEST_BASE} )
    {
         $env->{HTTP_X_FORWARDED_SCRIPT_NAME} = $env->{HTTP_REQUEST_BASE};
    }

    # Wrap in reverse proxy middleware and call the wrapped app
    my $app = Plack::Middleware::ReverseProxyPath->wrap($self->app);
    $app = Plack::Middleware::ReverseProxy->wrap($app);
    return $app->($env);
}

1;

__END__

=head1 DESCRIPTION

Modifies request headers supported by L<Dancer2> altered by reverse proxies before
wraping the request in the commonly used reverse proxy PSGI middlewares;
L<Plack::Middleware::ReverseProxy> and L<Plack::Middleware::ReverseProxyPath>.

=cut
