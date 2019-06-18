# ABSTRACT: create new Dancer2 application
package Dancer2::CLI::Command::gen;

use strict;
use warnings;

use App::Cmd::Setup -command;

use HTTP::Tiny;
use File::Find;
use File::Path 'mkpath';
use File::Spec::Functions;
use File::Share 'dist_dir';
use File::Basename qw/dirname basename/;
use Dancer2::Template::Simple;
use Module::Runtime 'require_module';

my $SKEL_APP_FILE = 'lib/AppFile.pm';

sub description { 'Helper script to create new Dancer2 applications' }

sub opt_spec {
    return (
        [ 'application|a=s', 'application name' ],
        [ 'directory|d=s',   'application folder (default: same as application name)' ],
        [ 'path|p=s',        'application path (default: current directory)',
            { default => '.' } ],
        [ 'overwrite|o',     'overwrite existing files' ],
        [ 'no-check|x',      'don\'t check latest Dancer2 version (requires internet)' ],
        [ 'skel|s=s',        'skeleton directory' ],
    );
}

sub validate_args {
    my ($self, $opt, $args) = @_;

    my $name = $opt->{application}
        or $self->usage_error('Application name must be defined');

    if ( $name =~ /[^\w:]/ || $name =~ /^\d/ || $name =~ /\b:\b|:{3,}/ ) {
        $self->usage_error(
            "Invalid application name.\n" .
            "Application names must not contain single colons, dots, " .
            "hyphens or start with a number.\n"
        );
    }

    my $path = $opt->{path};
    -d $path or $self->usage_error("directory '$path' does not exist");
    -w $path or $self->usage_error("directory '$path' is not writeable");

    if ( my $skel_path = $opt->{skel} ) {
        -d $skel_path
            or $self->usage_error("skeleton directory '$skel_path' not found");
    }
}

sub execute {
    my ($self, $opt, $args) = @_;
    $self->_version_check() unless $opt->{'no_check'};

    my $dist_dir = dist_dir('Dancer2');
    my $skel_dir = $opt->{skel} || catdir($dist_dir, 'skel');
    -d $skel_dir or die "$skel_dir doesn't exist";

    my $app_name = $opt->{application};
    my $app_file = _get_app_file($app_name);
    my $app_path = _get_app_path($opt->{path}, $app_name);

    if( my $dir = $opt->{directory} ) {
        $app_path = catdir( $opt->{path}, $dir );
    }

    my $files_to_copy = _build_file_list($skel_dir, $app_path);
    foreach my $pair (@$files_to_copy) {
        if ($pair->[0] =~ m/$SKEL_APP_FILE$/) {
            $pair->[1] = catfile($app_path, $app_file);
            last;
        }
    }

    my $vars = {
        appname          => $app_name,
        appfile          => $app_file,
        appdir           => File::Spec->rel2abs($app_path),
        perl_interpreter => _get_perl_interpreter(),
        cleanfiles       => _get_dashed_name($app_name),
        dancer_version   => $self->version(),
    };

    _copy_templates($files_to_copy, $vars, $opt->{overwrite});
    _create_manifest($files_to_copy, $app_path);
    _add_to_manifest_skip($app_path);

    if ( ! eval { require_module('YAML'); 1; } ) {
        print <<'NOYAML';
*****
WARNING: YAML.pm is not installed.  This is not a full dependency, but is highly
recommended; in particular, the scaffolded Dancer app being created will not be
able to read settings from the config file without YAML.pm being installed.

To resolve this, simply install YAML from CPAN, for instance using one of the
following commands:

  cpan YAML
  perl -MCPAN -e 'install YAML'
  curl -L http://cpanmin.us | perl - --sudo YAML
*****
NOYAML
    }

    print <<HOWTORUN;

Your new application is ready! To run it:

        cd $app_path
        plackup bin/app.psgi

If you need community assistance, the following resources are available:
- Dancer website: http://perldancer.org
- Mailing list: http://lists.preshweb.co.uk/mailman/listinfo/dancer-users
- IRC: irc.perl.org#dancer

Happy Dancing!

HOWTORUN

    return 0;
}

sub version {
    require_module('Dancer2');
    return Dancer2->VERSION;
}

# skel creation routines
sub _build_file_list {
    my ($from, $to) = @_;
    $from =~ s{/+$}{};
    my $len = length($from) + 1;

    my @result;
    my $wanted = sub {
        return unless -f;
        my $file = substr($_, $len);

        # ignore .git and git/*
        my $is_git = $file =~ m{^\.git(/|$)}
            and return;

        push @result, [ $_, catfile($to, $file) ];
    };

    find({ wanted => $wanted, no_chdir => 1 }, $from);
    return \@result;
}

sub _copy_templates {
    my ($files, $vars, $overwrite) = @_;

    foreach my $pair (@$files) {
        my ($from, $to) = @{$pair};
        if (-f $to && !$overwrite) {
            print "! $to exists, overwrite? [N/y/a]: ";
            my $res = <STDIN>; chomp($res);
            $overwrite = 1 if $res eq 'a';
            next unless ($res eq 'y') or ($res eq 'a');
        }

        my $to_dir = dirname($to);
        if (! -d $to_dir) {
            print "+ $to_dir\n";
            mkpath $to_dir or die "could not mkpath $to_dir: $!";
        }

        my $to_file = basename($to);
        my $ex = ($to_file =~ s/^\+//);
        $to = catfile($to_dir, $to_file) if $ex;

        print "+ $to\n";
        my $content;

        {
            local $/;
            open(my $fh, '<:raw', $from) or die "unable to open file `$from' for reading: $!";
            $content = <$fh>;
            close $fh;
        }

        if ($from !~ m/\.(ico|jpg|png|css|eot|map|swp|ttf|svg|woff|woff2|js)$/) {
            $content = _process_template($content, $vars);
        }

        open(my $fh, '>:raw', $to) or die "unable to open file `$to' for writing: $!";
        print $fh $content;
        close $fh;

        if ($ex) {
            chmod(0755, $to) or warn "unable to change permissions for $to: $!";
        }
    }
}

sub _create_manifest {
    my ($files, $dir) = @_;

    my $manifest_name = catfile($dir, 'MANIFEST');
    open(my $manifest, '>', $manifest_name) or die $!;
    print $manifest "MANIFEST\n";

    foreach my $file (@{$files}) {
        my $filename = substr $file->[1], length($dir) + 1;
        my $basename = basename $filename;
        my $clean_basename = $basename;
        $clean_basename =~ s/^\+//;
        $filename =~ s/\Q$basename\E/$clean_basename/;
        print {$manifest} "$filename\n";
    }

    close($manifest);
}

sub _add_to_manifest_skip {
    my $dir = shift;

    my $filename = catfile($dir, 'MANIFEST.SKIP');
    open my $fh, '>>', $filename or die $!;
    print {$fh} "^$dir-\n";
    close $fh;
}

sub _process_template {
    my ($template, $tokens) = @_;
    my $engine = Dancer2::Template::Simple->new;
    $engine->{start_tag} = '[d2%';
    $engine->{stop_tag} = '%2d]';
    return $engine->render(\$template, $tokens);
}

sub _get_app_path {
    my ($path, $appname) = @_;
    return catdir($path, _get_dashed_name($appname));
}

sub _get_app_file {
    my $appname = shift;
    $appname =~ s{::}{/}g;
    return catfile('lib', "$appname.pm");
}

sub _get_perl_interpreter {
    return -r '/usr/bin/env' ? '#!/usr/bin/env perl' : "#!$^X";
}

sub _get_dashed_name {
    my $name = shift;
    $name =~ s{::}{-}g;
    return $name;
}

# version check routines
sub _version_check {
    my $self = shift;
    my $version = $self->version();
    return if $version =~  m/_/;

    my $latest_version = 0;
    my $resp = _send_http_request('http://search.cpan.org/api/module/Dancer2');

    if ($resp) {
        if ( $resp =~ /"version" (?:\s+)? \: (?:\s+)? "(\d\.\d+)"/x ) {
            $latest_version = $1;
        } else {
            die "Can't understand search.cpan.org's reply.\n";
        }
    }

    if ($latest_version > $version) {
        print qq|
The latest stable Dancer2 release is $latest_version, you are currently using $version.
Please check http://search.cpan.org/dist/Dancer2/ for updates.

|;
    }
}

sub _send_http_request {
    my $url = shift;

    my $ua = HTTP::Tiny->new( timeout => 5 );

    my $response = $ua->get($url);
    return $response->{'success'} ? $response->{'content'} : undef;
}

1;
