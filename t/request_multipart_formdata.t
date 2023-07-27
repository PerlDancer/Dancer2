use strict;
use warnings;

use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw<is_coderef>;


{
    package MyApp;

    use Dancer2;
    our $entity;

    set engines => {
        serializer => {
            JSON => {
                pretty => 1,
            }
        }
    };
    set serializer => 'JSON';

   post '/' => sub {
      template 'index' => { 'title' => 'test_uploads' };
   };

}

my $app = MyApp->to_app;
ok( is_coderef($app), 'Got app' );

my $test = Plack::Test->create($app);

my $filename = 't/app.t';
my $res  = $test->request( POST '/', 
   "Content-Type" => 'multipart/form-data',
   Content => [ filename => [ $filename ] ] );
ok( $res->is_success, '[POST /] successful' );
