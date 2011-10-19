use strict;
use warnings;
use Test::More import => ['!pass'];
use File::Spec;

my @hooks = qw(
    before_file_render
    after_file_render
);

my $tests_flags = {};
{
    use Dancer;

    for my $hook (@hooks) {
        hook $hook => sub {
            $tests_flags->{$hook} ||= 0;
            $tests_flags->{$hook}++;
        };
    }

    get '/send_file' => sub {
        send_file(File::Spec->rel2abs(__FILE__), system_path => 1);
    };

    # make sure we compile all the apps without starting a webserver
    main->dancer_app->finish;
}

use Dancer::Test;

my $resp = dancer_response get => '/send_file';
is $resp->[0], 200;
like $resp->[2][0], qr{something in this file};

is $tests_flags->{before_file_render}, 1, "before_file_render was called";
is $tests_flags->{after_file_render}, 1, "after_file_render was called";

$resp = dancer_response get => '/file.txt';
is $resp->[0], 200;
is $resp->[2][0], "this is a public file\n";
is $tests_flags->{before_file_render}, 2, "before_file_render was called";
is $tests_flags->{after_file_render}, 2, "after_file_render was called";

done_testing;
