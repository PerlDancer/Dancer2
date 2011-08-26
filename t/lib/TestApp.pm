package t::lib::TestApp;
use Dancer;
# this app is intended to cover 100% of the DSL!

# hello route
get '/' => sub { app->name };

# /haltme should bounce to /
before sub {
    if (request->path_info eq '/haltme') {
        redirect '/';
        halt;
    }
};
get '/haltme' => sub { "should not be there" };

# some settings
set some_var => 1;
setting some_other_var => 1;

get '/config' => sub {
    return config->{some_var}.' '.config->{some_other_var};
};

# chained routes with pass
get '/user/**' => sub {
    my $user = params->{splat};
    var user => $user->[0][0];
    pass;
};

get '/user/*/home' => sub {
    my $user = var('user'); # should be set by the previous route
    "hello $user";
};

# post & dirname
post '/dirname' => sub {
    dirname('/etc/passwd');
};

# header
get '/header/:name/:value' => sub {
    header param('name') => param('value');
    1;
};

# push_header
get '/header/:name/:valueA/:valueB' => sub {
    push_header param('name') => param('valueA');
    push_header param('name') => param('valueB');
    1;
};

# header
get '/header_twice/:name/:valueA/:valueB' => sub {
    header param('name') => param('valueA');
    header param('name') => param('valueB');
    1;
};

# any
any ['get','post'], '/any' => sub {
    "Called with method ".request->method;
};

# true and false
get '/booleans' => sub {
    join(":", true, false);
};

1;
