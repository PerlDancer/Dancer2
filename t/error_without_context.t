#!perl
use strict;
use warnings;
use Test::More;
use Scalar::Util;
use Data::Dumper;    #temporary

use_ok('Dancer2::Core::Error');
note "test error without context";
{
    my $error = Dancer2::Core::Error->new(
        status  => 404,
        message => "No such file: `path'",

        #no context
    );

    #print Dumper $error;

    is( $error->show_errors, 0, 'show_errors defaults to false if no context' );
    my $response = $error->throw;
    is( blessed $response, 'Dancer2::Core::Response' );
    is( $response->status, 500 );                      #because show_errors off.
         #without context we have no template engine, so content is plain text
      #we could have a default template + template engine as in default_error_page
    ok( $response->content =~ /^Internal/ );

    #print Dumper $response;
}

{
    my $error = Dancer2::Core::Error->new(
        status      => 404,
        message     => "No such file: `path'",
        show_errors => 1

          #no context
    );
    is( $error->show_errors, 1, 'show_errors set to true' );
    ok( $error->content =~ m/\<\!DOCTYPE/, 'content looks like html' );
    #my $response = $error->throw;
    #print Dumper $error;
    #print Dumper $response;

}
done_testing;
