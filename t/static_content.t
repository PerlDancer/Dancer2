use strict;
use warnings;
use utf8;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{
    package PublicContent;
    use Dancer2;

    set public_dir => 't/corpus/static';

    get '/' => sub { return 'Welcome Home' };

}

my $test = Plack::Test->create( PublicContent->to_app );

subtest 'public content' => sub {
    my $res = $test->request( GET '/1x1.png' );
    is $res->code, 200, "200 response";
    my $last_modified = $res->header('Last-Modified');
    
    $res = $test->request( GET '/1x1.png', 'If-Modified-Since' => $last_modified );
    is $res->code, 304, "304 response";
};

done_testing();
