use Dancer;
use Data::Dumper;

use lib 'contrib::lib';

use contrib::lib::Foo;
use contrib::lib::Bar;
use contrib::lib::Pass;

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

