# ABSTRACT: helper for rendering HTTP status codes for Dancer2

package Dancer2::Core::HTTP;

use strict;
use warnings;

my %HTTP_CODES_AS_STR = (
    # informational
    100 => 'Continue',               # only on HTTP 1.1
    101 => 'Switching Protocols',    # only on HTTP 1.1
    102 => 'Processing',             # WebDAV; RFC 2518

    # processed
    200 => 'OK',
    201 => 'Created',
    202 => 'Accepted',
    203 => 'Non-Authoritative Information', # only on HTTP 1.1
    204 => 'No Content',
    205 => 'Reset Content',
    206 => 'Partial Content',
    207 => 'Multi-Status',           # WebDAV; RFC 4918
    208 => 'Already Reported',       # WebDAV; RFC 5842
    # 226 => 'IM Used'               # RFC 3229

    # redirections
    301 => 'Moved Permanently',
    302 => 'Found',
    303 => '303 See Other',          # only on HTTP 1.1
    304 => 'Not Modified',
    305 => '305 Use Proxy',          # only on HTTP 1.1
    306 => 'Switch Proxy',
    307 => 'Temporary Redirect',     # only on HTTP 1.1
    # 308 => 'Permanent Redirect'    # approved as experimental RFC

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
    418 => "I'm a teapot",             # RFC 2324
    # 419 => 'Authentication Timeout', # not in RFC 2616
    420 => 'Enhance Your Calm',
    422 => 'Unprocessable Entity',
    423 => 'Locked',
    424 => 'Failed Dependency',        # Also used for 'Method Failure'
    425 => 'Unordered Collection',
    426 => 'Upgrade Required',
    428 => 'Precondition Required',
    429 => 'Too Many Requests',
    431 => 'Request Header Fields Too Large',
    444 => 'No Response',
    449 => 'Retry With',
    450 => 'Blocked by Windows Parental Controls',
    451 => 'Unavailable For Legal Reasons',
    451 => 'Redirect',
    494 => 'Request Header Too Large',
    495 => 'Cert Error',
    496 => 'No Cert',
    497 => 'HTTP to HTTPS',
    499 => 'Client Closed Request',

    # problems with server
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    502 => 'Bad Gateway',
    503 => 'Service Unavailable',
    504 => 'Gateway Timeout',
    505 => 'HTTP Version Not Supported',
    506 => 'Variant Also Negotiates',
    507 => 'Insufficient Storage',
    508 => 'Loop Detected',
    509 => 'Bandwidth Limit Exceeded',
    510 => 'Not Extended',
    511 => 'Network Authentication Required',
    598 => 'Network read timeout error',
    599 => 'Network connect timeout error',
);

my %HTTP_CODES_AS_NUM = map +(
    $_ => $_,
    $HTTP_CODES_AS_STR{$_} => $_,
    lc( join '_', split /\W/, $HTTP_CODES_AS_STR{$_} ) => $_
), keys %HTTP_CODES_AS_STR;

for ( keys %HTTP_CODES_AS_NUM ) {
    $HTTP_CODES_AS_STR{$_} =
        $HTTP_CODES_AS_STR{ $HTTP_CODES_AS_NUM{$_} };
}

$HTTP_CODES_AS_NUM{error} = $HTTP_CODES_AS_NUM{internal_server_error};
$HTTP_CODES_AS_STR{error} = $HTTP_CODES_AS_STR{internal_server_error};

sub status { $_[1] && $HTTP_CODES_AS_NUM{ $_[1] } }

sub status_message { $_[1] && $HTTP_CODES_AS_STR{ $_[1] } }

1;

__END__

=func status(status_code)

    Dancer2::Core::HTTP->status(200); # returns 200

    Dancer2::Core::HTTP->status('Not Found'); # returns 404

    Dancer2::Core::HTTP->status('bad_request'); # 400

Returns a HTTP status code.  If given an integer, it will return the value it
received, else it will try to find the appropriate alias and return the correct
status.

=func status_message(status_code)

    Dancer2::Core::HTTP->status_message(200); # returns 'OK'

    Dancer2::Core::HTTP->status_message('error'); # returns 'Internal Server Error'

Returns the HTTP status message for the given status code.

=cut
