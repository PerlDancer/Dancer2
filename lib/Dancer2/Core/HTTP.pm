# ABSTRACT: helper for rendering HTTP status codes for Dancer2

package Dancer2::Core::HTTP;

use strict;
use warnings;

my $HTTP_CODES = {

    # informational
    # 100 => 'Continue', # only on HTTP 1.1
    # 101 => 'Switching Protocols', # only on HTTP 1.1

    # processed codes
    200 => 'OK',
    201 => 'Created',
    202 => 'Accepted',

    # 203 => 'Non-Authoritative Information', # only on HTTP 1.1
    204 => 'No Content',
    205 => 'Reset Content',
    206 => 'Partial Content',

    # redirections
    301 => 'Moved Permanently',
    302 => 'Found',

    # 303 => '303 See Other', # only on HTTP 1.1
    304 => 'Not Modified',

    # 305 => '305 Use Proxy', # only on HTTP 1.1
    306 => 'Switch Proxy',

    # 307 => '307 Temporary Redirect', # on HTTP 1.1

    # problems with request
    400 => 'Bad Request',
    401 => 'Unauthorized',
    402 => 'Payment Required',
    403 => 'Forbidden',
    404 => 'Not Found',
    405 => 'Method Not Allowed',
    406 => 'Not Acceptable',
    407 => 'Proxy Authentication Required',
    408 => 'Request Timeout',
    409 => 'Conflict',
    410 => 'Gone',
    411 => 'Length Required',
    412 => 'Precondition Failed',
    413 => 'Request Entity Too Large',
    414 => 'Request-URI Too Long',
    415 => 'Unsupported Media Type',
    416 => 'Requested Range Not Satisfiable',
    417 => 'Expectation Failed',

    # problems with server
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    502 => 'Bad Gateway',
    503 => 'Service Unavailable',
    504 => 'Gateway Timeout',
    505 => 'HTTP Version Not Supported',
};

for my $code ( keys %$HTTP_CODES ) {
    my $str_http_code = $HTTP_CODES->{$code};
    $HTTP_CODES->{$str_http_code} = $code;

    my $alias = lc join '_', split /\W/, $HTTP_CODES->{$code};
    $HTTP_CODES->{$alias} = $code;
}

$HTTP_CODES->{error} = $HTTP_CODES->{internal_server_error};

=func status(status_code)

    Dancer2::Core::HTTP->status(200); # returns 200

    Dancer2::Core::HTTP->status('Not Found'); # returns 404

    Dancer2::Core::HTTP->status('bad_request'); # 400

Returns a HTTP status code.  If given an integer, it will return the value it
received, else it will try to find the appropriate alias and return the correct
status.

=cut

sub status {
    my ( $class, $status ) = @_;
    return $status if $status =~ /^\d+/;
    if ( exists $HTTP_CODES->{$status} ) {
        return $HTTP_CODES->{$status};
    }
    return undef;
}

1;

