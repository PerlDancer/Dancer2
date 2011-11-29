package Dancer::Core::Error;
use Moo;
use Carp;
use Dancer::Moo::Types;
use Data::Dumper;

with 'Dancer::Core::Role::Hookable';

sub supported_hooks {
    qw/before_error_render after_error_render before_error_init/;
}

has show_errors => (
    is => 'ro',
    isa => sub { Bool(@_) },
);

has charset => (
    is => 'ro',
    isa => sub { Str(@_) },
    default => sub { 'UTF-8' },
);

has title => (
    is => 'rw',
    isa => sub { Str(@_) },
    lazy => 1,
    builder => '_build_title',
);

has error_template => (
    is => 'ro',
    isa => sub { ReadableFilePath(@_) },
    lazy => 1,
    builder => '_build_error_template',
);

sub _build_error_template {
    my ($self) = @_;
    my $template = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
<title>[% title %]</title>
<link rel="stylesheet" href="/css/[% style %].css" />
<meta http-equiv="Content-type" content="text/html; charset=' . $self->charset . '" />
</head>
<body>
<h1>[% title %]</h1>
<div id="content">
[% content %]
</div>
<div id="footer">
Powered by <a href="http://perldancer.org/">Dancer</a> [% version %]
</div>
</body>
</html>';
    return \$template;
}

sub _build_title {
    my ($self) = @_;
    "Error ".$self->code;
}

has type => (
    is => 'rw',
    isa => sub { Str(@_) },
);

has code => (
    is => 'ro',
    default => sub { 500 },
    isa => sub { Num(@_) },
);

has message => (
    is => 'rw',
    isa => sub { Str(@_) },
    lazy => 1,
    builder => '_build_message',
);

sub _build_message {
    my ($self) = @_;
    my $html_output = "<h2>" . $self->{type} . "</h2>";
    $html_output .= $self->backtrace;
    $html_output .= $self->environment;
    return $html_output;
}

has serializer => (
    is => 'ro',
    isa => sub { ConsumerOf('Dancer::Core::Role::Serializer', @_) },
);

has template => (
    is => 'ro',
    isa => sub { ConsumerOf('Dancer::Core::Role::Template', @_) },
);

has session => (
    is => 'ro',
    isa => sub { ConsumerOf('Dancer::Core::Role::Session') },
);

has context => (
    is => 'ro',
    isa => sub { ObjectOf('Dancer::Core::Context', @_) },
);

sub BUILD {
    my ($self) = @_;
    $self->execute_hooks('before_error_init', $self);
}

has exception => (
    is => 'rw',
    isa => sub { Str(@_) },
);

sub render {
    my $self = shift;

    $self->execute_hooks('before_error_render', $self);
    my $response = $self->_render_html();
    $self->execute_hooks('after_error_render', $response);
    
    return $response;
}


sub backtrace {
    my ($self) = @_;

    my $message =
      qq|<pre class="error">| . _html_encode($self->message) . "</pre>";

    # the default perl warning/error pattern
    my ($file, $line) = ($message =~ /at (\S+) line (\d+)/);

    # the Devel::SimpleTrace pattern
    ($file, $line) = ($message =~ /at.*\((\S+):(\d+)\)/)
      unless $file and $line;

    # no file/line found, cannot open a file for context
    return $message unless ($file and $line);

    # file and line are located, let's read the source Luke!
    my $fh = open_file('<', $file) or return $message;
    my @lines = <$fh>;
    close $fh;

    my $backtrace = $message;

    $backtrace
      .= qq|<div class="title">| . "$file around line $line" . "</div>";

    $backtrace .= qq|<pre class="content">|;

    $line--;
    my $start = (($line - 3) >= 0)             ? ($line - 3) : 0;
    my $stop  = (($line + 3) < scalar(@lines)) ? ($line + 3) : scalar(@lines);

    for (my $l = $start; $l <= $stop; $l++) {
        chomp $lines[$l];

        if ($l == $line) {
            $backtrace
              .= qq|<span class="nu">|
              . tabulate($l + 1, $stop + 1)
              . qq|</span> <span style="color: red;">|
              . _html_encode($lines[$l])
              . "</span>\n";
        }
        else {
            $backtrace
              .= qq|<span class="nu">|
              . tabulate($l + 1, $stop + 1)
              . "</span> "
              . _html_encode($lines[$l]) . "\n";
        }
    }
    $backtrace .= "</pre>";


    return $backtrace;
}

# private

sub tabulate {
    my ($number, $max) = @_;
    my $len = length($max);
    return $number if length($number) == $len;
    return " $number";
}

sub dumper {
    my $obj = shift;

    # Take a copy of the data, so we can mask sensitive-looking stuff:
    my %data     = %$obj;
    my $censored = _censor(\%data);

    #use Data::Dumper;
    my $dd = Data::Dumper->new([\%data]);
    $dd->Terse(1)->Quotekeys(0)->Indent(1);
    my $content = $dd->Dump();
    $content =~ s{(\s*)(\S+)(\s*)=>}{$1<span class="key">$2</span>$3 =&gt;}g;
    if ($censored) {
        $content
          .= "\n\nNote: Values of $censored sensitive-looking keys hidden\n";
    }
    return $content;
}

# Given a hashref, censor anything that looks sensitive.  Returns number of
# items which were "censored".
sub _censor {
    my $hash = shift;
    if (!$hash || ref $hash ne 'HASH') {
        carp "_censor given incorrect input: $hash";
        return;
    }

    my $censored = 0;
    for my $key (keys %$hash) {
        if (ref $hash->{$key} eq 'HASH') {
            $censored += _censor($hash->{$key});
        }
        elsif ($key =~ /(pass|card?num|pan|secret)/i) {
            $hash->{$key} = "Hidden (looks potentially sensitive)";
            $censored++;
        }
    }

    return $censored;
}

# Replaces the entities that are illegal in (X)HTML.
sub _html_encode {
    my $value = shift;

    $value =~ s/&/&amp;/g;
    $value =~ s/</&lt;/g;
    $value =~ s/>/&gt;/g;
    $value =~ s/'/&#39;/g;
    $value =~ s/"/&quot;/g;

    return $value;
}

sub _render_html {
    my $self = shift;

    # error_template defaults to something, always
    my $template_name = $self->error_template;
    my $ops           = {
        title   => $self->title,
        message => $self->message,
        code    => $self->code,
        defined $self->exception ? (exception => $self->exception) : (),
    };
    my $content = $self->template->apply_renderer($template_name, $ops);
    $self->context->response->status($self->code);
    $self->context->response->header('Content-Type' => 'text/html');
    return $content;
}

sub environment {
    my ($self) = @_;

    my $request = $self->context->request;
    my $r_env   = {};
    $r_env = $request->env if defined $request;

    my $env =
        qq|<div class="title">Environment</div><pre class="content">|
      . dumper($r_env)
      . "</pre>";
    my $settings =
        qq|<div class="title">Settings</div><pre class="content">|
      . dumper($self->app->settings)
      . "</pre>";
    my $source =
        qq|<div class="title">Stack</div><pre class="content">|
      . $self->get_caller
      . "</pre>";
    my $session = "";

    if ($self->session) {
        $session =
            qq[<div class="title">Session</div><pre class="content">]
          . dumper($self->session->data)
          . "</pre>";
    }
    return "$source $settings $session $env";
}

sub get_caller {
    my ($self) = @_;
    my @stack;

    my $deepness = 0;
    while (my ($package, $file, $line) = caller($deepness++)) {
        push @stack, "$package in $file l. $line";
    }

    return join("\n", reverse(@stack));
}

1;

__END__

=pod

=head1 NAME

Dancer::Error - class for representing fatal errors

=head1 SYNOPSIS

    # taken from send_file:
    use Dancer::Error;

    my $error = Dancer::Error->new(
        code    => 404,
        message => "No such file: `$path'"
    );

    Dancer::Response->set($error->render);

=head1 DESCRIPTION

With Dancer::Error you can throw reasonable-looking errors to the user instead
of crashing the application and filling up the logs.

This is usually used in debugging environments, and it's what Dancer uses as
well under debugging to catch errors and show them on screen.

=head1 ATTRIBUTES

=head2 code

The code that caused the error.

This is only an attribute getter, you'll have to set it at C<new>.

=head2 title

The title of the error page.

This is only an attribute getter, you'll have to set it at C<new>.

=head2 message

The message of the error page.

This is only an attribute getter, you'll have to set it at C<new>.

=head1 METHODS/SUBROUTINES

=head2 new

Create a new Dancer::Error object.

=head3 title

The title of the error page.

=head3 type

What type of error this is.

=head3 code

The code that caused the error.

=head3 message

The message that will appear to the user.

=head2 backtrace

Create a backtrace of the code where the error is caused.

This method tries to find out where the error appeared according to the actual
error message (using the C<message> attribute) and tries to parse it (supporting
the regular/default Perl warning or error pattern and the L<Devel::SimpleTrace>
output) and then returns an error-higlighted C<message>.

=head2 tabulate

Small subroutine to help output nicer.

=head2 dumper

This uses L<Data::Dumper> to create nice content output with a few predefined
options.

=head2 render

Renders a response using L<Dancer::Response>.

=head2 environment

A main function to render environment information: the caller (using
C<get_caller>), the settings and environment (using C<dumper>) and more.

=head2 get_caller

Creates a strack trace of callers.

=head2 _censor

An internal method that tries to censor out content which should be protected.

C<dumper> calls this method to censor things like passwords and such.

=head2 _html_encode

Internal method to encode entities that are illegal in (X)HTML. We output as
UTF-8, so no need to encode all non-ASCII characters or use a module.
FIXME : this is not true anymore, output can be any charset. Need fixing.

=head1 AUTHOR

Alexis Sukrieh

=head1 LICENSE AND COPYRIGHT

Copyright 2009-2010 Alexis Sukrieh.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

