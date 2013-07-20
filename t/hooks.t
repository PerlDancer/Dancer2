use strict;
use warnings;
use Test::More import => ['!pass'];
use File::Spec;

use Carp;

eval { require Template; Template->import(); 1 }
  or plan skip_all => 'Template::Toolkit probably missing';


my @hooks = qw(
  before_request
  after_request

  before_template_render
  after_template_render

  before_file_render
  after_file_render

  before_serializer
  after_serializer
);

my $tests_flags = {};
{
    use Dancer2;


    for my $hook (@hooks) {
        hook $hook => sub {
            $tests_flags->{$hook} ||= 0;
            $tests_flags->{$hook}++;
        };
    }

    # we set the engines after the hook, and that should work
    # thanks to the postponed hooks system
    set template   => 'template_toolkit';
    set serializer => 'JSON';

    get '/send_file' => sub {
        send_file( File::Spec->rel2abs(__FILE__), system_path => 1 );
    };

    get '/' => sub {
        "ok";
    };

    get '/template' => sub {
        template \"PLOP";
    };

    hook 'before_serializer' => sub {
        my $data = shift;
        push @{$data}, ( added_in_hook => 1 );
    };

    get '/json' => sub {
        [ foo => 42 ];
    };

    get '/intercepted' => sub {'not intercepted'};

    hook before => sub {
        my $c = shift;
        return unless $c->request->path eq '/intercepted';

        $c->response->content('halted by before');
        $c->response->halt;
    };

    # make sure we compile all the apps without starting a webserver
    main->dancer_app->finish;
}

use Dancer2::Test;

subtest 'request hooks' => sub {
    my $r = dancer_response get => '/';
    is $tests_flags->{before_request},     1,     "before_request was called";
    is $tests_flags->{before_serializer},  undef, "before_serializer undef";
    is $tests_flags->{after_serializer},   undef, "after_serializer undef";
    is $tests_flags->{before_file_render}, undef, "before_file_render undef";
};

subtest 'serializer hooks' => sub {
    require 'JSON.pm';
    my $r = dancer_response get => '/json';
    my $json = JSON::to_json( [ foo => 42, added_in_hook => 1 ] );
    is $r->content, $json, 'response is serialized';
    is $tests_flags->{before_serializer}, 1, 'before_serializer was called';
    is $tests_flags->{after_serializer},  1, 'after_serializer was called';
    is $tests_flags->{before_file_render}, undef, "before_file_render undef";
};

subtest 'file render hooks' => sub {
    my $resp = dancer_response get => '/send_file';
    is $tests_flags->{before_file_render}, 1, "before_file_render was called";
    is $tests_flags->{after_file_render},  1, "after_file_render was called";

    $resp = dancer_response get => '/file.txt';
    is $tests_flags->{before_file_render}, 2, "before_file_render was called";
    is $tests_flags->{after_file_render},  2, "after_file_render was called";
};

subtest 'template render hook' => sub {
    my $resp = dancer_response get => '/template';
    is $tests_flags->{before_template_render}, 1,
      "before_template_render was called";
    is $tests_flags->{after_template_render}, 1,
      "after_template_render was called";
};

subtest 'before can halt' => sub {
    my $resp = dancer_response get => '/intercepted';
    is join( "\n", @{ $resp->[2] } ) => 'halted by before';
};

done_testing;
