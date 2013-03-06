package t::lib::TestApp;
use Dancer2;

# this app is intended to cover 100% of the DSL!

# set some MIME aliases...
mime->add_type(foo => 'text/foo');
mime->add_alias(f => 'foo');

set 'default_mime_type' => 'text/bar';

# hello route
get '/' => sub { app->name };

# /haltme should bounce to /
hook 'before' => sub {
    if (request->path_info eq '/haltme') {
        redirect '/';
        halt;
    }
};
get '/haltme' => sub {"should not be there"};

hook 'after' => sub {
    my $response = shift;
    if (request->path_info eq '/rewrite_me') {
        $response->content("rewritten!");
    }
};
get '/rewrite_me' => sub {"body should not be this one"};


# some settings
set some_var           => 1;
setting some_other_var => 1;
set multiple_vars      => 4, can_be_set => 2;

get '/config' => sub {
    return
        config->{some_var} . ' '
      . config->{some_other_var} . ' and '
      . setting('multiple_vars')
      . setting('can_be_set');
};

if ($] >= 5.010) {

    # named captures
    get
      qr{/(?<class> usr | content | post )/(?<action> delete | find )/(?<id> \d+ )}x
      => sub {
        join(":", sort %{captures()});
      };
}

# chained routes with pass
get '/user/**' => sub {
    my $user = params->{splat};
    var user => $user->[0][0];
    pass;
};

get '/user/*/home' => sub {
    my $user = var('user');    # should be set by the previous route
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
any ['get', 'post'], '/any' => sub {
    "Called with method " . request->method;
};

# true and false
get '/booleans' => sub {
    join(":", true, false);
};

# mimes
get '/mime/:name' => sub {
    mime->for_name(param('name'));
};

# content_type
get '/content_type/:type' => sub {
    content_type param('type');
    1;
};

# prefix
prefix '/prefix' => sub {
    get '/bar' => sub {'/prefix/bar'};
    prefix '/prefix1' => sub {
        get '/bar' => sub {'/prefix/prefix1/bar'};
    };

    prefix '/prefix2';
    get '/foo' => sub {'/prefix/prefix2/foo'};
};

1;
