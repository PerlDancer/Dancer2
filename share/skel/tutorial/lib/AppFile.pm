package [d2% appname %2d];
use Dancer2;
use Dancer2::Plugin::DBIx::Class;
use Dancer2::Plugin::Auth::Tiny;
use Dancer2::Plugin::CryptPassphrase;
use Feature::Compat::Try;

get '/' => sub {
    # Give us the most recent first
    my @entries = resultset('Entry')->search(
        {},
        { order_by => { -desc => 'created_at' } },
    )->all;
    template 'index', { entries => \@entries };
};

get '/entry/:id[Int]' => sub {
    my $id = route_parameters->get('id');
    my $entry = resultset( 'Entry' )->find( $id );
    template 'entry', { entry => $entry };
};

get '/create' => needs login => sub {
    # Vars are passed to templates automatically
    template 'create_update', { post_to => uri_for '/create' };
};

post '/create' => needs login => sub {
    my $params = body_parameters();
    var $_ => $params->{ $_ } foreach qw< title summary content >;

    my @missing = grep { $params->{$_} eq '' } qw< title summary content >;
    if( @missing ) {
        var missing => join ",", @missing;
        warning "Missing parameters: " . var 'missing';
        forward '/create', {}, { method => 'GET' };
    }

    my $entry = do {
        try {
            resultset('Entry')->create( $params->as_hashref );
        }
        catch( $e ) {
            error "Database error: $e";
            var error_message => 'A database error occurred; your entry could not be created',
            forward '/create', {}, { method => 'GET' };
        }
    };

    debug 'Created entry ' . $entry->id . ' for "' . $entry->title . '"';
    redirect uri_for "/entry/" . $entry->id; # redirect does not need a return
};

get '/update/:id[Int]' => needs login => sub {
    my $id = route_parameters->get('id');
    my $entry = resultset( 'Entry' )->find( $id );
    var $_ => $entry->$_ foreach qw< title summary content >;
    template 'create_update', { post_to => uri_for "/update/$id" };
};

post '/update/:id[Int]' => needs login => sub {
    my $id = route_parameters->get('id');
    my $entry = resultset( 'Entry' )->find( $id );
    if( !$entry ) {
        status 'not_found';
        return "Attempt to update non-existent entry $id";
    }

    my $params = body_parameters();
    var $_ => $params->{ $_ } foreach qw< title summary content >;
    my @missing = grep { $params->{$_} eq '' } qw< title summary content >;
    if( @missing ) {
        var missing => join ",", @missing;
        warning "Missing parameters: " . var 'missing';
        forward "/update/$id", {}, { method => 'GET' };
    }

    try {
        $entry->update( $params->as_hashref );
    }
    catch( $e ) {
        error "Database error: $e";
        var error_message => 'A database error occurred; your entry could not be updated',
        forward "/update/$id", {}, { method => 'GET' };
    }

    debug 'Updated entry ' . $entry->id . ' for "' . $entry->title . '"';
    redirect uri_for "/entry/" . $entry->id; # redirect does not need a return
};

get '/delete/:id[Int]' => needs login => sub {
    my $id = route_parameters->get('id');
    my $entry = resultset( 'Entry' )->find( $id );
    template 'delete', { entry => $entry };
};

post '/delete/:id[Int]' => needs login => sub {
    my $id = route_parameters->get('id');
    my $entry = resultset( 'Entry' )->find( $id );
    if( !$entry ) {
        status 'not_found';
        return "Attempt to delete non-existent entry $id";
    }

    # Always default to not destroying data
    my $delete_it = body_parameters->get('delete_it') // 0;

    if( $delete_it ) {
        $entry->delete;
        redirect uri_for "/";
    } else {
        # Display our entry again
        redirect uri_for "/entry/$id";
    }
};

get '/login' => sub {
    template 'login' => { return_url => params->{ return_url } };
};

post '/login' => sub {
    my $username = body_parameters->get('username');
    my $password = body_parameters->get('password');
    my $return_url = body_parameters->get('return_url');

    my $user = resultset( 'User' )->find({ username => $username });
    if ( $user and verify_password( $password, $user->password) ) {
        app->change_session_id;
        session user => $username;
        info "$username successfully logged in";
        return redirect $return_url || '/';
    }
    else {
        warning "Failed login attempt for $username";
        template 'login' => { login_error => 1, return_url => $return_url };
    }
};

get '/logout' => sub {
    app->destroy_session;
    redirect uri_for "/";
};

true;

