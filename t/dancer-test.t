# who test the tester? We do!

use strict;
use warnings;
use File::Spec;
use File::Basename qw/dirname/;

BEGIN {
    # Disable route handlers so we can actually test route_exists
    # and route_doesnt_exist. Use config that disables default route handlers.
    $ENV{DANCER_CONFDIR} = File::Spec->catdir(dirname(__FILE__), 'dancer-test');
}

use Test::More tests => 49;

use Dancer2;
use Dancer2::Test;
use Dancer2::Core::Request;
use File::Temp;
use Encode;
use URI::Escape;

$Dancer2::Test::NO_WARN = 1;

my @routes = (
    '/foo',
    [ GET => '/foo' ],
    Dancer2::Core::Request->new(
        env => {
            'psgi.url_scheme' => 'http',
            REQUEST_METHOD    => 'GET',
            QUERY_STRING      => '',
            SERVER_NAME       => 'localhost',
            SERVER_PORT       => 5000,
            SERVER_PROTOCOL   => 'HTTP/1.1',
            SCRIPT_NAME       => '',
            PATH_INFO         => '/foo',
            REQUEST_URI       => '/foo',
        }
    ),
);
my $fighter = Dancer2::Core::Response->new(
    content => 'fighter',
    status  => 404,
);

route_doesnt_exist $_ for (@routes, $fighter);


get '/foo' => sub {'fighter'};

route_exists $_, "route $_ exists" for @routes;

$fighter->status(200);
push @routes, $fighter;

for (@routes) {
    my $response = dancer_response $_;
    isa_ok $response      => 'Dancer2::Core::Response';
    is $response->content => 'fighter';
}

response_content_is $_ => 'fighter', "response_content_is with $_" for @routes;
response_content_isnt $_ => 'platypus', "response_content_isnt with $_"
  for @routes;
response_content_like $_   => qr/igh/   for @routes;
response_content_unlike $_ => qr/ought/ for @routes;

response_status_is $_   => 200 for @routes;
response_status_isnt $_ => 203 for @routes;

response_headers_include $_ => [ Server => "Perl Dancer2 " . Dancer2->VERSION ]
  for @routes;

## Check parameters get through ok
get '/param' => sub { param('test') };
my $param_response =
  dancer_response( GET => '/param', { params => { test => 'hello' } } );
is $param_response->content, 'hello', 'PARAMS get echoed by route';

post '/upload' => sub {
    my $file = upload('test');
    return $file->content;
};
## Check we can upload files
my $file_response = dancer_response(
    POST => '/upload',
    {   files =>
          [ { filename => 'test.txt', name => 'test', data => 'testdata' } ]
    }
);
is $file_response->content, 'testdata', 'file uploaded with supplied data';

my $temp = File::Temp->new;
print $temp 'testfile';
close($temp);

$file_response =
  dancer_response( POST => '/upload',
    { files => [ { filename => $temp->filename, name => 'test' } ] } );
is $file_response->content, 'testfile', 'file uploaded with supplied filename';

## Check multiselect/multi parameters get through ok
get '/multi' => sub {
    my $t = param('test');
    return 'bad' if ref($t) ne 'ARRAY';
    my $p = join( '', @$t );
    return $p;
};
$param_response =
  dancer_response( GET => '/multi',
    { params => { test => [ 'foo', 'bar' ] } } );
is $param_response->content, 'foobar',
  'multi values for same key get echoed back';

my $russian_test =
  decode( 'UTF-8',
    uri_unescape("%D0%B8%D1%81%D0%BF%D1%8B%D1%82%D0%B0%D0%BD%D0%B8%D0%B5") );
$param_response =
  dancer_response( GET => '/multi',
    { params => { test => [ 'test/', $russian_test ] } } );
is $param_response->content, 'test/' . encode( 'UTF-8', $russian_test ),
  'multi utf8 value properly merge';

get '/headers' => sub {
    join " : ", request->header('X-Sent-By'), request->cookies->{foo};
};
note "extra headers in request"; {
    my $sent_by = 'Dancer2::Test';
    my $headers_test = dancer_response( GET => '/headers',
        {
            headers => [
                [ 'X-Sent-By' => $sent_by ],
                [ 'Cookie' => "foo=bar" ],
            ],
        }
    );
    is $headers_test->content, "$sent_by : bar",
        "extra headers included in request";
}
