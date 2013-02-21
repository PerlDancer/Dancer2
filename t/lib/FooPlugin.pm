package t::lib::FooPlugin;
use Dancer2::Plugin;

get '/sitemap' => sub {
    _html_sitemap();
};

sub _html_sitemap {
    join(', ', _retreive_get_urls());
}

register foo_wrap_request => sub {
    my ($self) = plugin_args(@_);
    return $self->request;
  },
  {is_global => 0};

register foo_route => sub {
    my ($self) = plugin_args(@_);
    $self->get('/foo', sub {'foo'});
};

# taken from SiteMap
sub _retreive_get_urls {
    my ($route, @urls);

    for my $app (@{runner->server->apps}) {
        my $routes = $app->routes;

        # push the static get routes into an array.
      get_route:
        for my $get_route (@{$routes->{get}}) {
            my $regexp = $get_route->regexp;

            # If the pattern is a true comprehensive regexp or the route
            # has a :variable element to it, then omit it.
            next get_route if ($regexp =~ m/[()[\]|]|:\w/);

            # If there is a wildcard modifier, then drop it and have the
            # full route.
            $regexp =~ s/\?//g;

            # Other than that, its cool to be added.
            push(@urls, $regexp)
              if !grep { $regexp =~ m/$_/i }
              @$Dancer2::Plugin::SiteMap::OMIT_ROUTES;
        }
    }

    return sort(@urls);
}


register_plugin for_versions => [2];
1;
