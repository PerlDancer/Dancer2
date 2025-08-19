package Dancer2::CLI::Gen;
# ABSTRACT: Create new Dancer2 application

use Moo;
use URI;
use HTTP::Tiny;
use Path::Tiny;
use JSON::MaybeXS;
use Dancer2::Template::Tiny;
use Module::Runtime qw( use_module is_module_name );
use CLI::Osprey
    desc => 'Helper script to create new Dancer2 applications';

# For git integration
use Symbol;
use IPC::Open3 qw();
use Try::Tiny;
use File::Which;

option application => (
    is            => 'ro',
    short         => 'a',
    doc           => 'application name',
    format        => 's',
    format_doc    => 'appname',
    required      => 1,
    spacer_before => 1,
);

option directory => (
    is         => 'ro',
    short      => 'd',
    doc        => 'application directory (default: same as application name)',
    format     => 's',
    format_doc => 'directory',
    required   => 0,
    default    => sub { my $self = shift; return $self->application; },
);

# This was causing conflict with Path::Tiny's path(), so renaming to avoid
# the overhead of making Path::Tiny an object.
option app_path => (
    is         => 'ro',
    short      => 'p',
    option     => 'path',
    doc        => 'application path (default: current directory)',
    format     => 's',
    format_doc => 'directory',
    required   => 0,
    default    => '.',
);

option overwrite => (
    is       => 'ro',
    short    => 'o',
    doc      => 'overwrite existing files',
    required => 0,
    default  => 0,
);

option no_check => (
    is       => 'ro',
    short    => 'x',
    doc      => "don't check latest Dancer2 version (default: check - requires internet)",
    required => 0,
    default  => 0,
);

option skel => (
    is         => 'ro',
    short      => 's',
    doc        => 'skeleton directory',
    format     => 's',
    format_doc => 'directory',
    required   => 0,
    default    => sub{
        my $self = shift;
        path( $self->parent_command->_dist_dir, 'skel' );
    },
);

option skel_name => (
    is         => 'ro',
    short      => 'n',
    doc        => 'skeleton name',
    format     => 's',
    format_doc => 'skelname',
    required   => 0,
    default    => 'default',
);

option docker => (
    is       => 'ro',
    short    => 'c',
    doc      => 'create a dockerfile (container definition)',
    required => 0,
    default  => 0,
);

option git => (
    is         => 'ro',
    short      => 'g',
    doc        => 'init git repository',
    required   => 0,
    default    => 0,
);

option remote => (
    is         => 'ro',
    short      => 'r',
    doc        => 'URI for git repository (implies -g)',
    format     => 's',
    format_doc => 'URI',
    required   => 0,
);

option no_package_files => (
    is       => 'ro',
    doc      => "don't create files needed for CPAN packaging",
    required => 0,
    default  => 0,
);

has _engine => (
    is => 'ro',
    default => sub {
        return Dancer2::Template::Tiny->new( config => { start_tag => '[d2%', end_tag => '%2d]' } );
    },
);

# Last chance to validate args before we attempt to do something with them
sub BUILD {
    my ( $self, $args ) = @_;

    $self->osprey_usage( 1, qq{
Invalid application name. Application names must not contain single colons,
dots, hyphens or start with a number.
    }) unless is_module_name( $self->application );

    if ( my $remote = $self->remote ) {
        my $scheme = URI->new( $remote )->scheme // $self->remote; # This feels dirty
        $self->osprey_usage( 1, "'$remote' must be a valid URI to git repository")
            unless $scheme =~ / ^ git \@ .+ : .+ \.git $ | ^ http /x;
    }

    my $path = $self->app_path;
    -d $path or $self->osprey_usage( 1, "path: directory '$path' does not exist" );
    -w $path or $self->osprey_usage( 1, "path: directory '$path' is not writeable" );

    if ( my $skel = $self->skel ) {
        -d $skel or $self->osprey_usage( 1, "skel: directory '$skel' not found" );
    }
}

sub run {
    my $self = shift;
    $self->_version_check unless $self->no_check;

    my $app_name = $self->application;
    my $app_file = $self->_get_app_file( $app_name );
    my $app_path = $self->_get_app_path( $self->app_path, $app_name );

    if( my $dir = $self->directory ) {
        $app_path = path( $self->app_path, $dir );
    }

    my $files_to_copy = $self->_build_file_list( $self->skel . '/' . $self->skel_name, $app_path );
    foreach my $pair( @$files_to_copy ) {
        if( $pair->[0] =~ m/lib\/AppFile.pm$/ ) {
            $pair->[1] = path( $app_path, $app_file );
            last;
        }
    }

    if( $self->docker ) {
        push @$files_to_copy, [ path( $self->parent_command->_dist_dir, 'docker/Dockerfile' ), "$app_name/Dockerfile" ];
    }

    my $vars = {
        appname          => $app_name,
        appfile          => $app_file->stringify,
        apppath          => $app_path,
        appdir           => File::Spec->rel2abs( $app_path ),
        apppath          => $app_path,
        perl_interpreter => $self->_get_perl_interpreter,
        cleanfiles       => $self->_get_dashed_name( $app_name ),
        dancer_version   => $self->parent_command->_dancer2_version,
        docker           => $self->docker,
    };

    $self->_copy_templates( $files_to_copy, $vars, $self->overwrite );
    unless( $self->no_package_files ) {
        $self->_create_manifest( $files_to_copy, $app_path );
        $self->_add_to_manifest_skip( $app_path );
    }

    $self->_check_git( $vars );
    $self->_check_yaml;
    $self->_how_to_run( $vars );
}

sub _check_git {
    my( $self, $vars ) = @_;

    if( my $remote = $self->remote or $self->git ) {
        my $app_name  = $vars->{ appname };
        my $git_error = qq{
*****

WARNING: Couldn't initialize a git repo despite being asked to do so.

To resolve this, cd to your application directory and run the following
commands:

  git init
  git add .
  git commit -m"Initial commit of $app_name by Dancer2"
};

        my $git = which 'git';
        -x $git or die "Can't execute git: $!";

        #my $dist_dir  = $self->parent_command->_dist_dir;
        my $app_path  = $vars->{ apppath };
        my $gitignore = path( $self->parent_command->_dist_dir, '.gitignore' );
        path( $gitignore )->copy( $app_path );

        chdir File::Spec->rel2abs( $app_path ) or die "Can't cd to $app_path: $!";
        if( _run_shell_cmd( 'git', 'init') != 0 or
            _run_shell_cmd( 'git', 'add', '.') != 0 or
            _run_shell_cmd( 'git', 'commit', "-m 'Initial commit of $app_name by Dancer2'" ) != 0 ) {
            print $git_error;
        }
        else {
            if( $self->remote &&
                _run_shell_cmd( 'git', 'remote', 'add', 'origin', $self->remote ) != 0 ) {
                print $git_error;
                print "  git remote add origin " . $self->remote . "\n";
            }
        }
        print "\n*****\n";
    }
}

sub _check_yaml {
    if ( ! eval { use_module( 'YAML' ); 1; } ) {
        print qq{
*****

WARNING: YAML.pm is not installed.  This is not a full dependency, but is highly
recommended; in particular, the scaffolded Dancer app being created will not be
able to read settings from the config file without YAML.pm being installed.

To resolve this, simply install YAML from CPAN, for instance using one of the
following commands:

  cpan YAML
  perl -MCPAN -e 'install YAML'
  curl -L https://cpanmin.us | perl - --sudo YAML

*****
};
    }
}

sub _how_to_run {
    my( $self, $vars ) = @_;

    my $app_path = $vars->{ apppath };
    my $app_name = $vars->{ appname };

    print "\nYour new application is ready! To run it:\n";

    if( $vars->{ docker } ) {
        my $image = lc $app_name;
        print qq{

        cd $app_path
        docker build -t ${image} .
        docker run -d -p 5000:4000 --name $app_name ${image}

where 5000 is the external port, and 4000 is the port your application
runs on inside of the container.

(note: you may need to run the docker commands with sudo)

You may also run your app without Docker:
};
    }

    my $install_deps = '';
    $install_deps = "\n        cpanm --installdeps ."
        if $self->skel_name ne 'default';

    print qq{
        cd $app_path$install_deps
        plackup bin/app.psgi

To access your application, point your browser to http://localhost:5000/

If you need community assistance, the following resources are available:
- Dancer website: https://perldancer.org
- GitHub: https://github.com/PerlDancer/Dancer2/
- Mailing list: https://lists.perldancer.org/mailman/listinfo/dancer-users
- IRC: irc.perl.org#dancer

Happy Dancing!

};
}

# skel creation routines
sub _build_file_list {
    my ( $self, $from, $to ) = @_;
    $from =~ s{/+$}{};

    my @result;
    my $iter = path( $from )->iterator({ recurse => 1 });
    while( my $file = $iter->() ) {
        warn "File not found: $file" unless $file->exists; # Paranoia
        next if $file->basename =~ m{^\.git(/|$)};
        next if $file->is_dir;

        my $filename = $file->relative( $from );
        push @result, [ $file, path( $to, $filename )];
    }
    return \@result;
}

sub _copy_templates {
    my ( $self, $files, $vars, $overwrite ) = @_;
    my $app_name  = $vars->{ appname };

    foreach my $pair (@$files) {
        my ( $from, $to ) = @{$pair};
        next if $self->no_package_files && $from =~ /MANIFEST\.SKIP$/;
        next if $self->no_package_files && $from =~ /Makefile.PL$/;

        if ( -f $to && !$overwrite ) {
            print "! $to exists, overwrite? (or rerun this command with -o) [N/y/a]: ";
            my $res = <STDIN>; chomp($res);
            $overwrite = 1 if $res eq 'a';
            next unless ( $res eq 'y' ) or ( $res eq 'a' );
        }

        $to =~ s/AppFile/$app_name/;
        my $to_dir = path( $to )->parent;
        if ( ! $to_dir->is_dir ) {
            print "+ $to_dir\n";
            $to_dir->mkpath;
        }

        # Skeleton files whose names are prefixed with + need to be executable, but we must strip
        # that from the name when copying them
        my $to_file = path( $to )->basename;
        my $ex      = ( $to_file =~ s/^\+// );
        $to         = path( $to_dir, $to_file ) if $ex;

        print "+ $to\n";
        my $content;
        {
            local $/;
            open( my $fh, '<:raw', $from ) or die "unable to open file `$from' for reading: $!";
            $content = <$fh>;
            close $fh;
        }

        if( $from !~ m/\.(db|ico|jpg|png|css|eot|map|swp|ttf|svg|woff|woff2|js)$/ ) {
            $content = $self->_process_template($content, $vars);
        }

        path( $to )->spew_raw( $content );
        if( $ex ) {
            $to->chmod( 0755 ) or warn "unable to change permissions for $to: $!";
        }
    }
}

sub _create_manifest {
    my ( $self, $files, $dir ) = @_;

    my $manifest_name = path( $dir, 'MANIFEST' );
    open( my $manifest, '>', $manifest_name ) or die $!;
    print $manifest "MANIFEST\n";

    foreach my $file( @{ $files } ) {
        my $filename       = path( $file->[1] )->relative( $dir );
        my $basename       = $filename->basename;
        my $clean_basename = $basename;
        $clean_basename    =~ s/^\+//;
        $filename          =~ s/\Q$basename\E/$clean_basename/;
        print {$manifest} "$filename\n";
    }

    close $manifest;
}

sub _add_to_manifest_skip {
    my ( $self, $dir ) = @_;

    my $filename = path( $dir, 'MANIFEST.SKIP' );
    open my $fh, '>>', $filename or die $!;
    print {$fh} "^$dir-\n";
    close $fh;
}

sub _process_template {
    my ( $self, $template, $tokens ) = @_;

    return $self->_engine->render( \$template, $tokens );
}

# These are good candidates to move to Dancer2::CLI if other commands
# need them later.
sub _get_app_path {
    my ( $self, $path, $appname ) = @_;
    return path( $path, $self->_get_dashed_name( $appname ));
}

sub _get_app_file {
    my ( $self, $appname ) = @_;
    $appname =~ s{::}{/}g;
    return path( 'lib', "$appname.pm" );
}

sub _get_perl_interpreter {
    return -r '/usr/bin/env' ? '#!/usr/bin/env perl' : "#!$^X";
}

sub _get_dashed_name {
    my ( $self, $name ) = @_;
    $name =~ s{::}{-}g;
    return $name;
}

# Other utility methods
sub _version_check {
    my $self    = shift;
    my $version = $self->parent_command->_dancer2_version;
    return if $version =~  m/_/;

    my $latest_version = 0;
    my $resp = HTTP::Tiny->new( timeout => 5 )->get( 'https://fastapi.metacpan.org/release/Dancer2' );
    if( $resp->{ success } && decode_json( $resp->{ content } )->{ version } =~ /(\d\.\d+)/ ) {
        $latest_version = $1;
        if ($latest_version gt $version) {
            print qq{
The latest stable Dancer2 release is $latest_version. You are currently using $version.
Please check https://metacpan.org/pod/Dancer2/ for updates.

};
        }
    } else {
        warn "\nCouldn't determine latest version of Dancer2. Please check your internet
connection, or pass -x to gen to bypass this check in the future.\n\n";

    }
}

# Shell out to run git
sub _run_shell_cmd {
    my @cmds = @_;

    my $exit_status = try {
        my $pid = IPC::Open3::open3(
            my $stdin,
            my $stdout,
            my $stderr = Symbol::gensym,
            @cmds,
        );

        waitpid( $pid, 0 );
        return $? >> 8;
    } catch {
        print STDERR "$_\n";
        return 1;
    };

    return $exit_status;
}

1;

