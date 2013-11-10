# ABSTRACT: create new Dancer2 application
package Dancer2::CLI::Command::gen;
use base Dancer2::CLI::Command;

use strict;
use warnings;

use File::Find;
use File::Path 'mkpath';
use File::Spec::Functions;
use File::ShareDir 'dist_dir';
use File::Basename qw/dirname basename/;
use Dancer2::Template::Simple;

my $SKEL_APP_FILE = 'lib/AppFile.pm';

sub description {
    return "Helper script to create new Dancer2 applications\n\nOptions:";
}

sub options {
    return (
        [ 'application|a=s', "the name of your application" ],
        [ 'path|p=s',        "the path where to create your application (current directory if not specified)", { default => '.' } ],
        [ 'overwrite|o',     "overwrite existing files" ],
    );
}

sub validate {
    my ($self, $opt, $args) = @_;

    my $name = $opt->{application};
    $name or $self->usage_error("Application name must be defined.\n");

    if ($name =~ /[^\w:]/ || $name =~ /^\d/ || $name =~ /\b:\b|:{3,}/) {
        $self->usage_error("Invalid application name.\nApplication names must not contain single colons, dots, hyphens or start with a number.\n");
    }

    my $path = $opt->{path};
    -d $path or $self->usage_error("directory '$path' does not exist");
    -w $path or $self->usage_error("directory '$path' is not writable");
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $dist_dir = dist_dir('Dancer2');
    my $skel_dir = catdir($dist_dir, 'skel');
    -d $skel_dir or die "$skel_dir doesn't exist";

    my $app_name = $opt->{application};
    my $app_file = _get_app_file($app_name);
    my $app_path = _get_app_path($opt->{path}, $app_name);

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

    unless (eval "require YAML") {
        print <<NOYAML;
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

    return 0;
}

# skel creation routines
sub _build_file_list {
    my ($from, $to) = @_;
    my $len = length($from) + 1;

    my @result;
    my $wanted = sub {
        return unless -f;
        my $file = substr($_, $len);
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
            open(my $fh, '<', $from) or die "unable to open file `$from' for reading: $!";
            $content = <$fh>;
            close $fh;
        }

        if ($from !~ m/\.(ico|jpg|css|js)$/) {
            $content = _process_template($content, $vars);
        }

        open(my $fh, '>', $to) or die "unable to open file `$to' for writing: $!";
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

    foreach (@{$files}) {
        print $manifest substr($_->[1], length($dir) + 1) . "\n";
    }

    close($manifest);
}

sub _process_template {
    my ($template, $tokens) = @_;
    my $engine = Dancer2::Template::Simple->new;
    $engine->{start_tag} = '[%';
    $engine->{stop_tag} = '%]';
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

1;
