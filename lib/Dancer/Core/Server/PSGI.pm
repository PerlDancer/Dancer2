# ABSTRACT: TODO

package Dancer::Core::Server::PSGI;
use Moo;
use Carp;
use Plack::Request;

with 'Dancer::Core::Role::Server';

=head1 DESCRIPTION

This is a server implementation for PSGI. It contains all the code to handle a
PSGI request.

=head1 SYNOPSIS

	sub start {
    	my $self = shift;
	    my $app  = $self->psgi_app();

	    foreach my $setting (qw/plack_middlewares plack_middlewares_map/) {
	        if (Dancer::Config::setting($setting)) {
	            my $method = 'apply_'.$setting;
	            $app = $self->$method($app);
	        }
	    }
    	return $app;
	}

	sub apply_plack_middlewares_map {
	    my ($self, $app) = @_;

	    my $mw_map = Dancer::Config::setting('plack_middlewares_map');

	    foreach my $req (qw(Plack::App::URLMap Plack::Builder)) {
	        croak "$req is needed to use apply_plack_middlewares_map"
	          unless Dancer::ModuleLoader->load($req);
	    }

	    my $urlmap = Plack::App::URLMap->new;

	    while ( my ( $path, $mw ) = each %$mw_map ) {
	        my $builder = Plack::Builder->new();
	        map { $builder->add_middleware(@$_) } @$mw;
	        $urlmap->map( $path => $builder->to_app($app) );
	    }

	    $urlmap->map('/' => $app) unless $mw_map->{'/'};
	    return $urlmap->to_app;
	}

	sub apply_plack_middlewares {
	    my ($self, $app) = @_;

	    my $middlewares = Dancer::Config::setting('plack_middlewares');
	
	    croak "Plack::Builder is needed for middlewares support"
	      unless Dancer::ModuleLoader->load('Plack::Builder');
	
	    my $builder = Plack::Builder->new();
	
	    ref $middlewares eq "ARRAY"
	      or croak "'plack_middlewares' setting must be an ArrayRef";

	    map {
	        Dancer::Logger::core "add middleware " . $_->[0];
	        $builder->add_middleware(@$_)
	    } @$middlewares;

	    $app = $builder->to_app($app);
	
	    return $app;
	}

	sub init_request_headers {
	    my ($self, $env) = @_;
	    my $plack = Plack::Request->new($env);
	    Dancer::SharedData->headers($plack->headers);
	}

=method name

The server's name: B<PSGI>.

=method start

Starts the server.

=cut

sub start {
    my ($self) = @_;
    $self->psgi_app;
}

sub _build_name {'PSGI'}

1;

