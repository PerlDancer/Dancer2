use Dancer2;
use Data::Dumper;
# use Dancer::Plugin::Foo;
# use Dancer::Plugin::Bar;

set content_type => 'text/plain';

get '/' => sub {
    template 'test'
};

get '/session' => sub {
    session value => "set by main";
    to_dumper(session());
};

get '/set/:name/:value' => sub {
    session( param('name') => param('value'));
};

get '/all_sessions' => sub {
    to_dumper(setting('session')->sessions);
};

dance;

__END__
# use Foo with => { session => engine('session') };

get '/' => sub {
    debug "in / route";
    to_yaml(session());
};

foo;
bar;

get '/req' => sub {
    wrap_request->env->{PATH_INFO};
};

get '/write/:name/:value' => sub {
    session param('name') => param('value');
};

start;

__END__
set serializer => 'JSON';

hook 'before_file_render' => sub {
    my $path = shift;
    warn "file rendering : $path";
};

hook 'after_file_render' => sub {
    my $resp = shift;
    warn "rendered ".Dumper($resp);
};

get '/send_file' => sub {
    # send_file '/etc/passwd', system_path => 1;
    send_file '/foo.txt',
        filename => 'fakefile.txt',
        content_type => 'application/data';
};

get '/' => sub {
    { foo => 42, bar => [ 1 .. 5]};
};

get '/s' => sub {
    to_json({x => 42});
};

get '/d' => sub {
    my $text = '{"bar":[1,2,3,4,5],"foo":42}';
    my $obj = from_json($text);
    Dumper($obj);
};

dance;
__END__
use lib 'contrib::lib';

use contrib::lib::Foo;
use contrib::lib::Bar;
use contrib::lib::Pass;

debug "starting to parse the app...";

before_template sub {
    my $tokens = shift;
    $tokens->{inbefore} = 'alexis';
};

get '/index' => sub {
    template 'index', { var => 42 };
};

my $count = 0;

before sub {
    $count++;
    debug "in before filter, count is $count";
};

before sub {
    if (request->path_info eq '/admin') {
        redirect '/';
        halt;
    }
};

set something_set_live => 42;

get '/config' => sub {
    my $a = app;
    return Dumper({
        app => $a,
        config => config(),
    });
};

get '/admin' => sub {
    "should not get there";
};

get '/count' => sub {
    debug "in route /count";
    "count is $count\n";
};

get '/' => sub {
    my $c = shift;
    use Data::Dumper;
    "This is Dancer 2! ".Dumper($c);
};

get '/bounce' => sub {
#    status '302';
#    header Location => 'http://perldancer.org';
    redirect 'http://perldancer.org';
};

get '/vars' => sub {
    Dumper(vars);
};

get '/var/:name/:value' => sub {
    var param('name') => param('value');
    redirect '/vars';
};

get "/hello/:name" => sub {
    params->{name}. " " . param('name');
};

prefix '/foo';

get '/bar' => sub {
    "This is Dancer 2, under /foo/bar";
};

prefix undef;

prefix '/lex' => sub {
    get '/ical' => sub { "lexical" };
};

get '/baz' => sub { "and /baz" };

start;

__END__
use strict;
use warnings;

use Dancer::Core::Server::Standalone;


my $app = Dancer::Core::App->new(name => 'main');
$app->add_route(method => 'get', regexp => '/', code => sub {"Dancer 2.0 Rocks!"});

my $server = Dancer::Core::Server::Standalone->new(app => $app);
$server->start;

