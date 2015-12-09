package Dancer2;

# ABSTRACT: Lightweight yet powerful web application framework

use 5.10.1;
use strict;
use warnings;
use List::Util 'first';
use Module::Runtime 'use_module';
use Import::Into;
use Dancer2::Core;
use Dancer2::Core::App;
use Dancer2::Core::Runner;
use Dancer2::FileUtils;

our $AUTHORITY = 'SUKRIA';

sub VERSION { shift->SUPER::VERSION(@_) || '0.000000_000' }

our $runner;

sub runner   {$runner}
sub psgi_app { shift->runner->psgi_app(@_) }

sub import {
    my ($class,  @args)   = @_;
    my ($caller, $script) = caller;

    my @final_args;
    my $clean_import;
    foreach my $arg (@args) {

        # ignore, no longer necessary
        # in the future these will warn as deprecated
        grep +($arg eq $_), qw<:script :syntax :tests>
          and next;

        if ($arg eq ':nopragmas') {
            $clean_import++;
            next;
        }

        if (substr($arg, 0, 1) eq '!') {
            push @final_args, $arg, 1;
        }
        else {
            push @final_args, $arg;
        }
    }

    $clean_import
      or $_->import::into($caller)
      for qw<strict warnings utf8>;

    scalar @final_args % 2
      and die q{parameters must be key/value pairs or '!keyword'};

    my %final_args = @final_args;

    my $appname = delete $final_args{appname};
    $appname ||= $caller;

    # never instantiated the runner, should do it now
    if (not defined $runner) {
        $runner = Dancer2::Core::Runner->new();
    }

    # Search through registered apps, creating a new app object
    # if we do not find one with the same name.
    my $app;
    ($app) = first { $_->name eq $appname } @{$runner->apps};

    if (!$app) {

        # populating with the server's postponed hooks in advance
        $app = Dancer2::Core::App->new(
            name            => $appname,
            caller          => $script,
            environment     => $runner->environment,
            postponed_hooks => $runner->postponed_hooks->{$appname} || {},
        );

        # register the app within the runner instance
        $runner->register_application($app);
    }

    _set_import_method_to_caller($caller);

    # use config dsl class, must extend Dancer2::Core::DSL
    my $config_dsl = $app->setting('dsl_class') || 'Dancer2::Core::DSL';
    $final_args{dsl} ||= $config_dsl;

    # load the DSL, defaulting to Dancer2::Core::DSL
    my $dsl = use_module($final_args{dsl})->new(app => $app);
    $dsl->export_symbols_to($caller, \%final_args);
}

sub _set_import_method_to_caller {
    my ($caller) = @_;

    my $import = sub {
        my ($self, %options) = @_;

        my $with = $options{with};
        for my $key (keys %$with) {
            $self->dancer_app->setting($key => $with->{$key});
        }
    };

    {
        ## no critic
        no strict 'refs';
        no warnings 'redefine';
        *{"${caller}::import"} = $import;
    }
}

1;

__END__

=encoding UTF-8

=head1 SYNOPSIS

    get '/' => sub { 'Hello, world!' };

=head1 DESCRIPTION

Dancer2 is a lightweight micro web framework for Perl. It is the new
generation of L<Dancer> and replaces it.

If you are converting a L<Dancer> application to L<Dancer2>, the
L<Dancer2::Manual::Migration> document covers the changes you might
need to make in your code.

=head1 Scaffolding a new application

While you can start a Dancer web application in any directory structure,
there is a recommended structure and an application (C<dancer2>) that
will scaffold a directory using this structure:

    dancer2 -a MyApp

This will create a directory structure with the following important
elements:

=over 4

=item * F<config.yml> and F<environments>

The main configuration file with some sample configuration to help get
you started, and a diretory containing additional configuration files
that will be loaded depending on the L<Plack> environment your server
starts in (B<production> or B<development>).

Note: The L<Starman> web server uses the C<deployment> environment
value.

=item * F<public>

A directory for your static assets like javascript, images, css,
and even two scripts to be used for easily configuring your application
for a CGI or FastCGI setup.

=item * F<lib>

A directory for your routing and controller logic.

=item * F<views>

A directory containing all your templates, including a sample design
with which to start.

=item * F<bin>

This directory will have a PSGI handler script you could use for
configuring your application on a PSGI server, such as L<Starman>.

=item * F<t>

Some basic sample tests. As you progress with your application, you
might want to write additional tests and this should give you a good
start.

=item * F<cpanfile>

A simple L<Module::CPANfile> file to help you package your application
with L<Carton>.

=item * F<Makefile.PL>

A packaging file to help you package your application in a CPAN-like
structure.

=back

=head1 Apps

All Dancer2 web applications are composed of containers called Dancer
Applications (I<Apps>).

These Apps provide keywords for creating your web application and
contain several components, specifically B<Engines>, B<Routes>,
and B<Hooks>.

Web applications are made out of either one or more Dancer applications,
while each Dancer Application is self-contained, including its own
configuration, its own engine instances, its own routing endpoints, and
its own hooks.

You can, however, spread a single Dancer Application across multiple
files in order to make your code easier to maintain. This is explained
below under I<Extending an application> section.

=head2 Engines

Engines provide many of the logistics of a common web application. There
are specifically four engine types.

=over 4

=item * B<Template>

Providing rendering of templates to produce formatted data, usually HTML.

=item * B<Logger>

Making it trivial to log messages from the web application.

=item * B<Session>

Making it easy to create a stateful web application by storing and
retrieving stateful information.

=item * B<Serializer>

Automatically serializing and deserializing data, helpful when writing
an web API application.

=back

=head2 Routes

Routes are the endpoints in your application. It is the paths that the
clients reach and they also contain the logic of what to do when that
happens.

=head2 Hooks

Hooks are additional pieces of code that run in several steps along the
way, such as before or after a template is rendered, before or after a
route is executed, or in several other situations.

Defining hooks allows you to have these events trigger your code.

=head1 Creating an application

In order to create a new Dancer2 Application, all you need is to import
the Dancer2 package:

    use Dancer2;

This will create a new L<Dancer2::Core::App> object somewhere in memory
(you needn't concern yourself with it) and you will be able to serve
this to a web server in order to run a full fledged web application.

When you import L<Dancer2>, you also receive additional pragmas
(specifically L<strict>, L<warnings>, and L<utf8>) with it since those
are common and helpful.

    use Dancer2;

    # exactly the same as:
    use strict;
    use warnings;
    use utf8;
    use Dancer2;

=head2 Import options

There are several import options that affect how your application is
created.

=over 4

=item * C<:nopragmas>

If you do not want Dancer2 to import any pragmas for you, you can
provide the C<:nopragmas> flag when importing:

    use strict;
    use warnings;
    no warnings 'uninitialized'; # for example...
    use Dancer2 ':nopragmas';

In this case, Dancer2 will not enable uninitialized warnings.

=item * C<appname>

Control the application class, allows merging into existing Apps.

Please see below under I<Extending an application> section.

=back

=head2 Configuration

You can configure your Dancer App in two ways:

=over 4

=item * Configuration files

The main configuration file (F<config.yml>) and the additional
environment-based configuration files (F<production>, F<development>,
etc.) allow you to change the settings in the app, such as the application
name, enable or disable features, or configure engines. You may even use
them to provide information for your own application.

These will be loaded when the application loads so it will be available
as soon as possible.

    # under config.yml
    template: "template_toolkit"

You can then reach the values of the configuration file using the
C<config> keyword.

    package MyApp;
    use Dancer2;
    my $template_engine_class = config->{'template'}; # "template_toolkit"

Note that C<config> will not I<change> configuration, only retrieve it.

=item * C<set> keyword

One of the keywords that Dancer2 provides you is C<set>, which can be used
in order to define configuration, much like the configuration files allow
you to do.

    package MyApp;
    use Dancer2;
    set template => 'template_toolkit';

Configuration created with C<set> is available after the application is
created, which might be too late for you (such as with plugins that need
a configuration when loading). You can use the configuration files in that
case.

Some configuration options can trigger events. In the case of
C<template>, for example, Dancer2 will create a new instance of the
template system you requested.

    package MyApp;
    use Dancer2; # template engine created

    set template => 'new_template_system'; # new engine instantiated

The C<config> keyword will provide access for all the configuration
created by the C<set> keyword.

=back

=head2 Extending an application

When Dancer2 creates an App, the application name will be based on the
package it is imported in.

    use Dancer2; # default package: "main"

or:

    package MyApp;
    use Dancer2; # App based on "MyApp"

Multiple packages yield multiple applications:

    # MyApp1.pm:
    package MyApp1;
    use Dancer2;

    # MyApp2.pm:
    package MyApp2;
    use Dancer2;

If you to extend a single application within multiple packages, you can
merge them together using the C<appname> option:

    # MyApp.pm:
    package MyApp;
    use Dancer2;
    use MyApp::Extra;

    # MyApp/Extra.pm:
    package MyApp::Extra;
    use Dancer2 appname => 'MyApp'; # merge into "MyApp" application

This will create a single application spread across two packages.

=head1 Running an application

There are two ways to run your Dancer2 applications: The old way and the
new way.

The old way (involving the `dance` keyword) is not recommended (and thus
not documented here), but it is still available for compatibility's sake.
Instead we present the preferred way: using L<Plack>, which is
automatically installed with L<Dancer2>.

=head2 Development server

In order to run the development server, you need to run `plackup` on a
PSGI application file. One is created for you when you scaffold a new
application using the `dancer2` command line application.

    plackup bin/app.psgi

This works by calling the method `to_app` on the Dancer Application. You
can write your own by doing the same:

    # MyApp.pm:
    use Dancer2;
    ... # your application is here

    # app.psgi:
    use MyApp;
    MyApp->to_app;

You may now run the script from the command line:

    plackup app.psgi

I<(The file extension is meaningless to Plack and is only there as an
indicator.)>

`plackup` has many options, but a note-worthy one here is the
auto-loading parameter, which restarts the development server as soon
as it identifies you changed a file:

    plackup -R lib,bin

This monitors the F<lib> and F<bin> directories for file changes. The
templates directory doesn't need to be monitored since template changed
do not require restarting the web server.

=head2 Production server

PSGI servers (L<Starman>, L<Twiggy>, L<Corona>, L<Starlet>, L<Gazelle>,
uWSGI, and more.) all run PSGI applications natively. You should only
serve the handler script above.

If you want to run your application on a server that does not have native
PSGI support, you can still run it as a CGI or FastCGI application. The
scaffolded structure `dancer2` command line creates appropriate files
that can be used as handlers in those cases.

=head1 Plugins

Plugins have the ability of adding additional keywords or hooks to an
application to ease the development or provide seamless integration.

For example, a plugin could provide a keyword that creates objects from
configuration settings or generate endpoints to your application in a
specific way.

Read more on how to write plugins in L<Dancer2::Plugin>.

=head1 Routes

Routes compose the endpoints your application has.

Routes have three main parts: B<Method>, B<Path>, and B<Callback>.

    get '/' => sub {...};

In the above example, the method is B<GET>, the path is B</>, and the
callback is the C<sub> provided at the end.

=head2 Method

A path is defined by the method it serves. Dancer2 provides you with
keywords for each method in order to define a route for that method.

The following keywords are available:

=over 4

=item * C<get>

Handles GET methods.

=item * C<post>

Handles POST methods.

=item * C<put>

Handles PUT methods.

=item * C<patch>

Handles PATCH methods.

=item * C<del>

Handles DELETE methods.

=item * C<any>

The C<any> keyword can handle any methods you want, whether all of them
or only a subset:

    # handle all methods
    any '/' => sub {...};

    # handle only GET and POST
    any [ 'get', 'post' ] => sub {...};

=back

=head2 Path

Dancer supports a sophisticated path spec, allowing you to define
variables - named or anonymous.

=head3 Static paths

Static paths are simple strings:

    get '/view/' => sub {...};

This will match the explicit path, F</view/>.

=head3 Variables

The path spec supports several ways of specifying variables in your
endpoints, allowing you to create dynamic paths.

=head4 Named placeholders

Named placeholders are the most common way of specifying variables
in your path. You can then retrieve those variables with the
C<route_parameters> keyword.

    get '/:greeting' => sub {
        my $greeting = route_parameters->get('greeting');
    };

If you go to the path F</hello>, the variable C<$greeting> will be
B<hello>.

You can have as many variables as you want:

    get '/:greeting/:name' => sub {
        my $greeting = route_parameters->get('greeting');
        my $name     = route_parameters->get('name');
    };

If you use the same placeholder string, C<get> will only return the
last match in the path.

Since C<route_parameters> returns L<Hash::MultiValue>, you can use
it as a hash directly as well:

    get '/:greeting/:name' => sub {
        my $greeting = route_parameters->{'greeting'};
        my $name     = route_parameters->{'name'};

        # or a hash slice
        my ( $greeting, $name ) = @{route_parameters()}{qw<greeting name>};
    };

=head4 Splat (Anonymous Placeholders)

The keyword C<splat> returns a B<list> of all the anonymous variables
matched.

    get '/*' => sub {
        my ($greeting) = splat;
    };

    get '/*/*' => sub {
        my ( $greeting, $name ) = splat;
    };

You can use as many as you like, but remember it will B<always>
return a list, never a scalar.

=head4 Megasplat (Greedy Placeholders)

The Megasplat is used as a way to capture as many matches as possible,
otherwise known as I<greediness>. This way, Dancer will grab every
path segment (delimited by forward slashes) separately.

In this case, C<splat> will still return a list, but where a megasplat
indicator is present (C<**>), it will provide an array reference.

    get '/**' => sub {
        my @segments = splat;
        my ( $greeting, $name ) = @{ $segments[0] };
    };

The reason is simple: a regular match and a greedy match are not the
same and they can be mixed together:

    get '/*/**' => sub {
        my ( $greeting, $parts ) = splat;
        my ( $title, $name ) = @{$parts};
    };

You can, of course, mix all of these together.

    get '/*/**/*/:name' => sub {...};

=head4 Regular expressions

Since this is Perl, we allow full power to those in need. You can use
regular expression objects (created with C<qr>) to specify your route:

    get qr{^/view/$} => sub {...};

You will need to anchor your regular expressions yourself, in order to
allow you to provide path segments in regular expressions too.

    get qr{/view/} => sub {...};

This will match both F</view/> and F</new/view/here>.

Any capturing done in regular expressionos are available using the
C<splat> keyword described above:

    # /view/10XR
    get qr{^/view/(\d\d\w{2})$} => sub {
        my ($id) = splat; # "10XR"
    };

If you're using perl 5.10 and above, named captures are available
using the C<captures> keyword:

    # /view/10XR
    get qr{^/view/(?<id>\d\d\w)$} => sub {
        my ($id) = captures->{'id'}; # "10XR"
    };

=head3 Prefix

Prefixes can be used to reduce repetition

    prefix '/hello' => sub {
        get '/world'    => sub {
            # /hello/world
            ...
        },

        get '/sunshine' => sub {
            # /hello/sunshine
            ...
        },
    };

You can also use variables in prefixes:

    prefix '/:greeting' => sub {
        get '/world'    => sub {
            # /hello/world
            # /hey/world
            my $greeting = route_parameters->get('greeting');
            "$greeting, World!";
        },
    };

=head2 Handler

The handler is code that will be executed when a request matches
a route. The return value of the handler will be the content returned
to the user for the request.

    get '/' => sub {
        return "Hello, is it me your'e looking for?";
    };

You will likely return HTML:

    get '/' => sub {
        return '<html><body>Do not do this, see below!</body></html>';
    };

You will most often use C<template> in order to render templates and
return their HTML content as the response:

    get '/' => sub {
        template 'index'; # render views/index.tt
    };

I<(The extension will be determined by the template engine you're
using.)>

The C<template> keyword also accepts variables for rendering:

    get '/' => sub {
        my $now = time;
        template index => { now => $now };
    };

The C<template> keyword will automatically render the template inside
a B<layout>. The default is F<main>, but that can also be configured.

You can also control the layout per rendering:

    get '/' => sub {
        template index => { name => 'Sawyer' }, { layout => 'mobile' };
    };

You can also use other keywords to control the flow of requests and
responses, such as returning a redirect to a different URL. They are
described below under B<Control Flow>.

=head3 Parameters

While you have full access to the underlying core objects representing
the request (using C<request>) and the response (using C<response>),
you will probably use the parameters the most.

There are three keywords for parameters, depending on where they are
provided. All three return L<Hash::MultiValue> objects in order to
prevent implicit context. If you do not know what this means, don't
worry about it.

=over 4

=item * C<route_parameters>

Route parameters are parameters that matched your route path. They are
described above under B<Named placeholders>. Here is a recap:

    get '/:name' => sub {
        # /Sawyer
        my $name = route_parameters->get('name');
        ...
    };

=item * C<query_parameters>

Query parameters are part of the query string and the usual parameters
sent.

Since a user may send a single value or multiple values, you can
use C<get> or C<get_all> in order to receive the appropriate amount:

    get '/user' => sub {
        # /user?username=xsawyerx&hobbies=hacking&hobbies=running
        my $username = query_parameters->get('username');
        my @hobbies  = query_parameters->get_all('hobbies');
        ...
    };

Note that, by definition of L<Hash::MultiValue>, the C<get> method on
C<query_parameters> will B<always> return a single value in a scalar,
while the C<get_all> method will B<always> return an array, even if
only a single value was sent - or even none, for that matter.

=item * C<body_parameters>

Body parameters are parameters that were received in the body of a
request (sometimes known as "request content", "request body", or
"data section").

    post '/user' => sub {
        # Request body:
        # "username=xsawyerx&hobbies=hacking&hobbies=running"
        my $username = body_parameters->get('username');
        my @hobbies  = body_parameters->get_all('hobbies');
        ...
    };

B<Note:> If you receive a request with a body that does not conform to
web parameters specification (such as a string, possibly a serialized
value), you will not be able to use C<body_parameters> to retrieve it,
since it's not a key and value. You can instead use the C<request>
keyword to retrieve the content:

    post '/update' => sub {
        # Request body:
        # "this is not a key and value pair"
        my $content = request->body;
        ...
    };

A common mistake is to send JSON as a serialized string and expect it
to be automatically available as parameters (this can be done using the
L<Dancer2::Serializer::JSON> functionality).

You can use the C<from_json> and C<to_json> helpers provided.

    post '/update' => sub {
        # Request body:
        # '{"status":"changed","value":-10}'
        my $parameters = from_json( request->body );

        return to_json( {
            success => 1,
        } );
    };

It is subject to the same L<Hash::MultiValue> principles explained
under C<query_parameters> above.

=back

=head3 Control Flow

There are several keywords meant to help you control the flow of the
request, including redirecting the user or redirecting a request
interally.

=over 4

=item * C<send_error>

You can return an error directly to the user using C<send_error>

    get '/' => sub {
        my @names = query_parameters->get_all('name');

        @names == 1
            or send_error('Incorrect number of users');

        ...
    };

You will notice that C<send_error> returns right away and once it is
called, a repsonse will be returned to your user. You need not include
a C<return> statement.

=item * C<redirect>

You can return a status telling the user you would like them to reach
a different URL instead:

    post '/login' => sub {
        my $user = body_parameters->get('user');
        my $pass = body_parameters->get('pass');

        # check user or return to login page with error
        check_user( $user, $pass )
            or redirect '/login?error=FailToConnect';

        ...
    };

The C<redirect> will return and once executed, the rest of the code
will not be run.

=item * C<forward>

The C<forward> keyword is an internal redirect, allowing you to cause
a redirect internally that the user cannot see. This is often used to
form a pattern called B<chained methods>.

    get '/' => sub {
        user_is_logged_in()
            and return template dashboard => { connected_user() };

        # the same as going to /login, without doing so
        forward '/login';
    };

Notice that when calling C<forward>, a response does not return to
the user, and the user will not see the new path once the response does
reach them.

=item * C<pass>

If there are two paths that could handle a URL, the first one registered
will be reached. However, it can indicate that it refuses to serve the
response. It can do that once it runs some code.

This also allows to generate B<chained methods> but in a much less
elegent way.

    get '/:name' => sub {
        if ( route_parameters->get('name') eq 'Sawyer' ) {
            return template sawyer => {};
        }

        # try to find something else to handle this
        pass;
    };

    get '/*' => sub {
        my ($item) = splat;
        template failsafe => { msg => "Cannot handle item: $item" };
    };

The key difference between C<forward> and C<pass> is that C<forward>
requests a specific path from the top. C<pass> simply asks the
dispatcher to continue trying to match the request to another route
from that point (avoiding routes it already tried before).

If not match can be made after a C<pass>, the application will return
a B<404>.

=item * C<halt>

The C<halt> keyword allows you to stop a current running request. It
immediatly returns and the B<after> hook will not be called.

    get '/' => sub {
        # run no further
        halt;

        # this line does not get called
        return "You never see this";
    };

All the information that was collected meanwhile for the response (such
as additional response headers, specific status you explicitly set with
the C<status> keyword, content you may have set manually, etc.)
will be used to create the response the user will receive.

You can also use this within the context of a B<before> hook, but it
is not recommended.

=back

=head2 Keeping information

There are several ways to maintain information in your application,
whehther it's throughout a request or between requests.

=head3 C<vars>

The first method, using C<var> and C<vars>, helps maintain information
for the life-cycle of a request. When you define something with C<var>
it is available for additional routes that handle a current request.

    get '/' => sub {
        var time => scalar time;
        forward('/handle');
    };

    get '/handle' => sub {
        my $time = vars->{'time'};
    };

This might seem as though it is only useful when calling C<forward> and
C<pass>, but a better usage of it is setting up scoped variables in
a B<before> hook.

Assuming our web application is an API in which every reqquest goes
to the database. This means that connecting to the database is something
we do in every route. We can use the B<before> in order to connect to
the database. Then in the route, we can use the handle we created during
that request (in the B<before> hook) in order to make a database call:

    hook before => sub {
        # create a variable "dbh" which will be the database handle
        var dbh => connect_db( config->{'db_conn'} );
    };

    get '/users' => sub {
        # we can now use that using vars()
        my $sth = vars->{'dbh'}->prepare(...);
        ...
    };

Once the request returns a response, the variable we created will
automatically be cleaned up.

=head3 Cookies

Cookies can be used to keep information on the client side in the
browser. Dancer provides two keywords for all Cookie-related actions:

=over 4

=item * C<cookie>

You can create new cookies or access existing ones using the C<cookie>
keyword:

    # create a new cookie
    cookie lang => 'fr-FR';

    # create a cookie with an expiration
    cookie lang => 'fr-FR', expires => '2 hours';

The options available for cookies are: C<path>, C<expires>, C<domain>,
C<secure>, and C<http_only>. You can read more about the options
available in L<Dancer2::Core::Cookie>.

    # retrieve a cookie
    my $cookie = cookie 'lang';

When you call C<cookie> on an existing key, you receive a cookie
object (of type L<Dancer2::Core::Cookie>). You can then call attributes
to receive specific details about the cookie:

    my $cookie_name   = $cookie->name;
    my $cookie_domain = $cookie->domain;
    my $cookie_path   = $cookie->path;

The C<value> attribute (the most useful one) is context sensitive.
If you provided a cookie value which is a key/value URI pair, and you
call C<value> in scalar context, only the first will be returned. If
you call it in list context, all values will be returned.

    # setting a URI key/value pair as the value
    cookie token => 'name=Sawyer&username=xsawyerx';

    # retrieving the first one
    my $value = $cookie->value;
    # $value is now 'name=Sawyer'

    # retrieving all values
    my @values = $cookie->value;
    # @values is now ( 'name=Sawyer', 'username=xsawyerx'

=item * C<cookies>

The C<cookies> keyword allows to access all cookie objects. It returns
a hashref of all objects based on their name:

    get '/some_action' => sub {
        my $cookie = cookies->{'token'};
        my $value  = $cookie->value;
        return $value;
    };

=back

=head3 Sessions

Sessions store information about the user on the server side and provide
an ID in a user cookie. When a user returns with the cookie containing
the ID, Dancer can locate their session information and retrieve it.

You can create a session using the C<session> keyword:

    post '/login' => sub {
        my $username = body_parameters->get('username');
        my $password = body_parameters->get('password');

        my $user = check_user( $username, $password )
            or redirect '/login';

        session user => $user;
        redirect '/';
    };

The C<session> keyword can access a key and value to store in the
internal storage. It will add a cookie for the user which will contain
the ID it uses to find the storage.

When you call C<session> with only a key, it will try and find the
appropriate storage and retrieve the data.

    get '/' => sub {
        my $user = session 'user'
            or redirect '/login';

        ...
    }

If you want to delete a key from the session, you can set it explicitly
to C<undef>:

    session user => undef; # delete "user" in the storage

To clear the session completely, you can call C<destroy_session> on
the C<app> itself:

    get '/logout' => sub {
        app->destroy_session;
    };

If called without parameters, the C<session> keyword will return an
object representing the session, including all the data relating to the
session. The type is L<Dancer2::Core::Session>.

    get '/introspect' => sub {
        my $session = session;
        $session->expires;
        $session->id;
    };

Note: Dancer comes with a default simple memory-based session engine,
to help you get started. Once you're ready, you should use a
production-level session engine.

=head2 Hooks

Hooks allow you to run code at certain points in the cycle of a request.
Dancer provides several hooks and plugins can provide additional hooks
for events that happen during the work of the plugin.

=over 4

=item * C<before>

    hook before => sub {
        ...
    };

The C<before> hook is run after Dancer decided what route needs to be
called, but before calling it. If you have a 404, the C<before> hook
will not be called.

The before hook provides a place to create variables which will be
available to the called route, as explained under C<vars> above.

=item * C<after>

    hook after => sub {
        ...
    };

The C<after> hook is run after a response was created, but before it
is sent back to the user.

=item * C<before_template_render>

    hook before_template_render => sub {
        my $tokens = shift;
        my $now    = time;
        $tokens->{'now'} = $now;
    };

The C<before_template_render> hook is called before a template is
rendered.  It receives the tokens that will be sent to the template
(as a hashref) so you could modify them to provide additional default
variables for the template.

=back

=head1 SECURITY REPORTS

If you need to report a security vulnerability in Dancer2, send all pertinent
information to L<mailto:dancer-security@dancer.pm>. These matters are taken
extremely seriously, and will be addressed in the earliest timeframe possible.

=head1 SUPPORT

You are welcome to join our mailing list.
For subscription information, mail address and archives see
L<http://lists.preshweb.co.uk/mailman/listinfo/dancer-users>.

We are also on IRC: #dancer on irc.perl.org.

=head1 AUTHORS

=head2 CORE DEVELOPERS

    Alberto Simões
    Alexis Sukrieh
    Damien Krotkine
    David Precious
    Franck Cuny
    Jason A. Crome
    Mickey Nasriachi
    Peter Mottram (SysPete)
    Russell Jenkins
    Sawyer X
    Stefan Hornburg (Racke)
    Steven Humphrey
    Yanick Champoux

=head2 CORE DEVELOPERS EMERITUS

    David Golden

=head2 CONTRIBUTORS

    A. Sinan Unur
    Abdullah Diab
    Achyut Kumar Panda
    Ahmad M. Zawawi
    Alex Beamish
    Alexander Karelas
    Alexander Pankoff
    Alexandr Ciornii
    Andrew Beverley
    Andrew Grangaard
    Andrew Inishev
    Andrew Solomon
    Andy Jack
    Ashvini V
    B10m
    Bas Bloemsaat
    baynes
    Ben Hutton
    Ben Kaufman
    biafra
    Blabos de Blebe
    Breno G. de Oliveira
    cdmalon
    Celogeek
    Cesare Gargano
    Charlie Gonzalez
    chenchen000
    Chi Trinh
    Christian Walde
    Christopher White
    cloveistaken
    Colin Kuskie
    cym0n
    Dale Gallagher
    Dan Book (Grinnz)
    Daniel Böhmer
    Daniel Muey
    Daniel Perrett
    Dave Jacoby
    Dave Webb
    David (sbts)
    David Steinbrunner
    David Zurborg
    Davs
    Deirdre Moran
    Dennis Lichtenthäler
    Dinis Rebolo
    dtcyganov
    Elliot Holden
    Erik Smit
    Fayland Lam
    ferki
    Gabor Szabo
    geistteufel
    Gideon D'souza
    Gil Magno
    Glenn Fowler
    Graham Knop
    Gregor Herrmann
    Grzegorz Rożniecki
    Hobbestigrou
    Hunter McMillen
    ice-lenor
    Ivan Bessarabov
    Ivan Kruglov
    JaHIY
    Jakob Voss
    James Aitken
    James Raspass
    James McCoy
    Jason Lewis
    Javier Rojas
    Jean Stebens
    Jens Rehsack
    Joel Berger
    Johannes Piehler
    Jonathan Cast
    Jonathan Scott Duff
    Joseph Frazer
    Julien Fiegehenn (simbabque)
    Julio Fraire
    Kaitlyn Parkhurst (SYMKAT)
    kbeyazli
    Keith Broughton
    lbeesley
    Lennart Hengstmengel
    Ludovic Tolhurst-Cleaver
    Mario Zieschang
    Mark A. Stratman
    Marketa Wachtlova
    Masaaki Saito
    Mateu X Hunter
    Matt Phillips
    Matt S Trout
    Maurice
    MaxPerl
    Ma_Sys.ma
    Menno Blom
    Michael Kröll
    Michał Wojciechowski
    Mike Katasonov
    Mohammad S Anwar
    mokko
    Nick Patch
    Nick Tonkin
    Nigel Gregoire
    Nikita K
    Nuno Carvalho
    Olaf Alders
    Olivier Mengué
    Omar M. Othman
    pants
    Patrick Zimmermann
    Pau Amma
    Paul Clements
    Paul Cochrane
    Paul Williams
    Pedro Bruno
    Pedro Melo
    Philippe Bricout
    Ricardo Signes
    Rick Yakubowski
    Ruben Amortegui
    Sakshee Vijay (sakshee3)
    Sam Kington
    Samit Badle
    Sebastien Deseille (sdeseille)
    Sergiy Borodych
    Shlomi Fish
    Slava Goltser
    Snigdha
    Steve Dondley
    Tatsuhiko Miyagawa
    Timothy Alexis Vass
    Tina Müller
    Tom Hukins
    Upasana Shukla
    Utkarsh Gupta
    Vernon Lyon
    Victor Adam
    Vince Willems
    Vincent Bachelier
    xenu
    Yves Orton
