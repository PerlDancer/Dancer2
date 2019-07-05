package Dancer2::Core::Error;
# ABSTRACT: Class representing fatal errors

use Moo;
use Carp;
use Dancer2::Core::Types;
use Dancer2::Core::HTTP;
use Data::Dumper;
use Dancer2::FileUtils qw/path open_file/;
use Sub::Quote;
use Module::Runtime 'require_module';
use Ref::Util qw< is_hashref >;
use Clone qw(clone);

has app => (
    is        => 'ro',
    isa       => InstanceOf['Dancer2::Core::App'],
    predicate => 'has_app',
);

has show_errors => (
    is      => 'ro',
    isa     => Bool,
    default => sub {
        my $self = shift;

        $self->has_app
            and return $self->app->setting('show_errors');
    },
);

has charset => (
    is      => 'ro',
    isa     => Str,
    default => sub {'UTF-8'},
);

has type => (
    is      => 'ro',
    isa     => Str,
    default => sub {'Runtime Error'},
);

has title => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_title',
);

sub _build_title {
    my ($self) = @_;
    my $title = 'Error ' . $self->status;
    if ( my $msg = Dancer2::Core::HTTP->status_message($self->status) ) {
        $title .= ' - ' . $msg;
    }

    return $title;
}

has template => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_error_template',
);

sub _build_error_template {
    my ($self) = @_;

    # look for a template named after the status number.
    # E.g.: views/404.tt  for a TT template
    my $engine = $self->app->template_engine;
    return $self->status
      if $engine->pathname_exists( $engine->view_pathname( $self->status ) );

    return;
}

has static_page => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_static_page',
);

sub _build_static_page {
    my ($self) = @_;

    # TODO there must be a better way to get it
    my $public_dir = $ENV{DANCER_PUBLIC}
      || ( $self->has_app && $self->app->config->{public_dir} );

    my $filename = sprintf "%s/%d.html", $public_dir, $self->status;

    open my $fh, '<', $filename or return;

    local $/ = undef;    # slurp time

    return <$fh>;
}

sub default_error_page {
    my $self = shift;

    require_module('Template::Tiny');

    my $uri_base = $self->has_app && $self->app->has_request ?
        $self->app->request->uri_base : '';

    # GH#1001 stack trace if show_errors is true and this is a 'server' error (5xx)
    my $show_fullmsg = $self->show_errors && $self->status =~ /^5/;
    my $opts = {
        title    => $self->title,
        charset  => $self->charset,
        content  => $show_fullmsg ? $self->full_message : _html_encode($self->message) || 'Wooops, something went wrong',
        version  => Dancer2->VERSION,
        uri_base => $uri_base,
    };

    Template::Tiny->new->process( \<<"END_TEMPLATE", $opts, \my $output );
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="[% charset %]">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes">
  <title>[% title %]</title>
  <link rel="stylesheet" href="[% uri_base %]/css/error.css">
</head>
<body>
<h1>[% title %]</h1>
<div id="content">
[% content %]
</div>
<div id="footer">
Powered by <a href="http://perldancer.org/">Dancer2</a> [% version %]
</div>
</body>
</html>
END_TEMPLATE

    return $output;
}

# status and message are 'rw' to permit modification in core.error.before hooks
has status => (
    is      => 'rw',
    default => sub {500},
    isa     => Num,
);

has message => (
    is      => 'rw',
    isa     => Str,
    lazy    => 1,
    default => sub { '' },
);

sub full_message {
    my ($self) = @_;
    my $html_output = "<h2>" . $self->type . "</h2>";
    $html_output .= $self->backtrace;
    $html_output .= $self->environment;
    return $html_output;
}

has serializer => (
    is        => 'ro',
    isa       => Maybe[ConsumerOf['Dancer2::Core::Role::Serializer']],
    builder   => '_build_serializer',
);

sub _build_serializer {
    my ($self) = @_;

    $self->has_app && $self->app->has_serializer_engine
        and return $self->app->serializer_engine;

    return;
}

sub BUILD {
    my ($self) = @_;

    $self->has_app &&
      $self->app->execute_hook( 'core.error.init', $self );
}

has exception => (
    is        => 'ro',
    isa       => Str,
    predicate => 1,
    coerce    => sub {
        # Until we properly support exception objects, we shouldn't barf on
        # them because that hides the actual error, if object overloads "",
        # which most exception objects do, this will result in a nicer string.
        # other references will produce a meaningless error, but that is
        # better than a meaningless stacktrace
        return "$_[0]"
    }
);

has response => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $serializer = $self->serializer;
        # include server tokens in response ?
        my $no_server_tokens = $self->has_app
            ? $self->app->config->{'no_server_tokens'}
            : defined $ENV{DANCER_NO_SERVER_TOKENS}
                ? $ENV{DANCER_NO_SERVER_TOKENS}
                : 0;
        return Dancer2::Core::Response->new(
            server_tokens => !$no_server_tokens,
            ( serializer => $serializer )x!! $serializer
        );
    }
);

has content_type => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->serializer
            ? $self->serializer->content_type
            : 'text/html'
    },
);

has content => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_content',
);

sub _build_content {
    my $self = shift;

    # return a hashref if a serializer is available
    if ( $self->serializer ) {
        my $content = {
            message => $self->message,
            title   => $self->title,
            status  => $self->status,
        };
        $content->{exception} = $self->exception
          if $self->has_exception;
        return $content;
    }

    # otherwise we check for a template, for a static file,
    # for configured error_template, and, if all else fails,
    # the default error page
    if ( $self->has_app and $self->template ) {
        # Render the template using apps' template engine.
        # This may well be what caused the initial error, in which
        # case we fall back to static page if any error was thrown.
        # Note: this calls before/after render hooks.
        my $content = eval {
            $self->app->template(
                $self->template,
                {   title     => $self->title,
                    content   => $self->message,
                    exception => $self->exception,
                    status    => $self->status,
                }
            );
        };
        $@ && $self->app->engine('logger')->log( warning => $@ );

        # return rendered content unless there was an error.
        return $content if defined $content;
    }

    # It doesn't make sense to return a static page for a 500 if show_errors is on
    if ( !($self->show_errors && $self->status eq '500') ) {
         if ( my $content = $self->static_page ) {
             return $content;
         }
    }

    if ($self->has_app && $self->app->config->{error_template}) {
        my $content = eval {
            $self->app->template(
                $self->app->config->{error_template},
                {   title     => $self->title,
                    content   => $self->message,
                    exception => $self->exception,
                    status    => $self->status,
                }
            );
        };
        $@ && $self->app->engine('logger')->log( warning => $@ );

        # return rendered content unless there was an error.
        return $content if defined $content;
    }

    return $self->default_error_page;
}

sub throw {
    my $self = shift;
    $self->response(shift) if @_;

    $self->response
        or croak "error has no response to throw at";

    $self->has_app &&
        $self->app->execute_hook( 'core.error.before', $self );

    my $message = $self->content;

    $self->response->status( $self->status );
    $self->response->content_type( $self->content_type );
    $self->response->content($message);

    $self->has_app &&
        $self->app->execute_hook('core.error.after', $self->response);

    $self->response->is_halted(1);
    return $self->response;
}

sub backtrace {
    my ($self) = @_;

    my $message = $self->message;
    if ($self->exception) {
        $message .= "\n" if $message;
        $message .= $self->exception;
    }
    $message ||= 'Wooops, something went wrong';

    my $html = '<pre class="error">' . _html_encode($message) . "</pre>\n";

    # the default perl warning/error pattern
    my ($file, $line) = $message =~ /at (\S+) line (\d+)/;
    # the Devel::SimpleTrace pattern
    ($file, $line) = $message =~ /at.*\((\S+):(\d+)\)/ unless $file and $line;

    # no file/line found, cannot open a file for context
    return $html unless $file and $line;

    # file and line are located, let's read the source Luke!
    my $fh = eval { open_file('<', $file) } or return $html;
    my @lines = <$fh>;
    close $fh;

    $html .= qq|<div class="title">$file around line $line</div>|;

    # get 5 lines of context
    my $start = $line - 5 > 1 ? $line - 5 : 1;
    my $stop = $line + 5 < @lines ? $line + 5 : @lines;

    $html .= qq|<pre class="content"><table class="context">\n|;
    for my $l ($start .. $stop) {
        chomp $lines[$l - 1];

        $html .= $l == $line ? '<tr class="errline">' : '<tr>';
        $html .= "<th>$l</th><td>" . _html_encode($lines[$l - 1]) . "</td></tr>\n";
    }
    $html .= "</table></pre>\n";

    return $html;
}

sub dumper {
    my $obj = shift;

    # Take a copy of the data, so we can mask sensitive-looking stuff:
    my $data     = clone($obj);
    my $censored = _censor( $data );

    #use Data::Dumper;
    my $dd = Data::Dumper->new( [ $data ] );
    my $hash_separator = '  @@!%,+$$#._(--  '; # Very unlikely string to exist already
    my $prefix_padding = '  #+#+@%.,$_-!((  '; # Very unlikely string to exist already
    $dd->Terse(1)->Quotekeys(0)->Indent(1)->Sortkeys(1)->Pair($hash_separator)->Pad($prefix_padding);
    my $content = _html_encode( $dd->Dump );
    $content =~ s/^.+//;   # Remove the first line
    $content =~ s/\n.+$//; # Remove the last line
    $content =~ s/^\Q$prefix_padding\E  //gm; # Remove the padding
    $content =~ s{^(\s*)(.+)\Q$hash_separator}{$1<span class="key">$2</span> =&gt; }gm;
    if ($censored) {
        $content
          .= "\n\nNote: Values of $censored sensitive-looking keys hidden\n";
    }
    return $content;
}

sub environment {
    my ($self) = @_;

    my $stack = $self->get_caller;
    my $settings = $self->has_app && $self->app->settings;
    my $session = $self->has_app && $self->app->_has_session && $self->app->session->data;
    my $env = $self->has_app && $self->app->has_request && $self->app->request->env;

    # Get a sanitised dump of the settings, session and environment
    $_ = $_ ? dumper($_) : '<i>undefined</i>' for $settings, $session, $env;

    return <<"END_HTML";
<div class="title">Stack</div><pre class="content">$stack</pre>
<div class="title">Settings</div><pre class="content">$settings</pre>
<div class="title">Session</div><pre class="content">$session</pre>
<div class="title">Environment</div><pre class="content">$env</pre>
END_HTML
}

sub get_caller {
    my ($self) = @_;
    my @stack;

    my $deepness = 0;
    while ( my ( $package, $file, $line ) = caller( $deepness++ ) ) {
        push @stack, "$package in $file l. $line";
    }

    return join( "\n", reverse(@stack) );
}

# private

# Given a hashref, censor anything that looks sensitive.  Returns number of
# items which were "censored".

sub _censor {
    my $hash = shift;
    my $visited = shift || {};

    unless ( $hash && is_hashref($hash) ) {
        carp "_censor given incorrect input: $hash";
        return;
    }

    my $censored = 0;
    for my $key ( keys %$hash ) {
        if ( is_hashref( $hash->{$key} ) ) {
            if (!$visited->{ $hash->{$key} }) {
                # mark the new ref as visited
                $visited->{ $hash->{$key} } = 1;

                $censored += _censor( $hash->{$key}, $visited );
            }
        }
        elsif ( $key =~ /(pass|card?num|pan|secret)/i ) {
            $hash->{$key} = "Hidden (looks potentially sensitive)";
            $censored++;
        }
    }

    return $censored;
}

# Replaces the entities that are illegal in (X)HTML.
sub _html_encode {
    my $value = shift;

    return if !defined $value;

    $value =~ s/&/&amp;/g;
    $value =~ s/</&lt;/g;
    $value =~ s/>/&gt;/g;
    $value =~ s/'/&#39;/g;
    $value =~ s/"/&quot;/g;

    return $value;
}

1;

__END__

=head1 SYNOPSIS

    # taken from send_file:
    use Dancer2::Core::Error;

    my $error = Dancer2::Core::Error->new(
        status    => 404,
        message => "No such file: `$path'"
    );

    Dancer2::Core::Response->set($error->render);

=head1 DESCRIPTION

With Dancer2::Core::Error you can throw reasonable-looking errors to the user
instead of crashing the application and filling up the logs.

This is usually used in debugging environments, and it's what Dancer2 uses as
well under debugging to catch errors and show them on screen.


=method my $error=new Dancer2::Core::Error(status    => 404, message => "No such file: `$path'");

Create a new Dancer2::Core::Error object. For available arguments see ATTRIBUTES.

=method supported_hooks ();

=attr show_errors

=attr charset

=attr type

The error type.

=attr title

The title of the error page.

This is only an attribute getter, you'll have to set it at C<new>.

=attr status

The status that caused the error.

This is only an attribute getter, you'll have to set it at C<new>.

=attr message

The message of the error page.

=method throw($response)

Populates the content of the response with the error's information.
If I<$response> is not given, acts on the I<app>
attribute's response.

=method backtrace

Show the surrounding lines of context at the line where the error was thrown.

This method tries to find out where the error appeared according to the actual
error message (using the C<message> attribute) and tries to parse it (supporting
the regular/default Perl warning or error pattern and the L<Devel::SimpleTrace>
output) and then returns an error-highlighted C<message>.

=head2 dumper

This uses L<Data::Dumper> to create nice content output with a few predefined
options.

=method environment

A main function to render environment information: the caller (using
C<get_caller>), the settings and environment (using C<dumper>) and more.

=method get_caller

Creates a stack trace of callers.

=func _censor

An private function that tries to censor out content which should be protected.

C<dumper> calls this method to censor things like passwords and such.

=func my $string=_html_encode ($string);

Private function that replaces illegal entities in (X)HTML with their
escaped representations.

html_encode() doesn't do any UTF black magic.

=cut
