package Dancer2::Core::Role::HasLocation;
# ABSTRACT: Role for application location "guessing"

use Carp ();
use Moo::Role;
use Sub::Quote 'quote_sub';
use Path::Tiny ();
use Dancer2::Core::Types;

# the path to the caller script/app
# Note: to remove any ambiguity between the accessor for the
# 'caller' attribute and the core function caller(), explicitly
# specify we want the function 'CORE::caller' as the default for
# the attribute.
has caller => (
    is      => 'ro',
    isa     => Str,
    default => quote_sub( q{
        require Path::Tiny;
        my ( $caller, $script ) = CORE::caller;
        Path::Tiny::path($script)->relative->stringify;
    } ),
);

has location => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_location',
);

has _location_path => (
    is       => 'ro',
    lazy     => 1,
    builder  => '_build_location_path',
    init_arg => undef,
);

sub _build_location_path {
    my $self = shift;
    return Path::Tiny::path( $self->location );
}

# Config file basenames a Dancer2 app root may hold. Keep this in sync with
# Config::Any->extensions, which is what Dancer2::ConfigReader actually reads.
my @_config_files = map "config.$_",
    qw< cnf conf ini json jsn pl perl xml yml yaml >;

# Directories a Dancer2 app root may hold. These are precisely the things
# 'location' is used to resolve, so a directory holding one of them is a
# directory worth calling the app root.
my @_app_dirs = qw< environments views public >;

# Does this directory look like the root of a Dancer2 application?
#
# Historically the only test was "holds both lib/ and bin/". That is a poor
# proxy: it matches every Perl distribution root, most home directories, /usr
# and /usr/local. It went unnoticed for years because the upward walk in
# _build_location was effectively stalling, so it rarely got the chance to
# leave the script's own directory. Once the walk started working the weak
# test began selecting directories far above the real app. See GH #1781.
sub _is_app_root {
    my $dir = shift;

    # explicit marker, placed by 'dancer2 gen' and by hand; always definitive
    $dir->child('.dancer')->is_file
        and return 1;

    # actual Dancer2 artifacts
    $dir->child($_)->is_dir and return 1 for @_app_dirs;
    $dir->child($_)->is_file and return 1 for @_config_files;

    # Legacy heuristic, kept for apps that carry no Dancer2 artifacts at all.
    # Checked last so anything above only wins when it is found closer to the
    # script. blib/ is skipped: it holds lib/ and bin/, but never views/ or
    # public/, so it is never the app root.
    return $dir !~ m![\\/]blib[\\/]?$!
        && $dir->child('lib')->is_dir
        && $dir->child('bin')->is_dir;
}

# FIXME: i hate you most of all -- Sawyer X
sub _build_location {
    my $self   = shift;
    my $script = $self->caller;

    # default to the dir that contains the script...
    my $location = Path::Tiny::path($script)->parent;

    $location->is_dir
        or Carp::croak("Caller $script is not an existing file");

    # Walk up looking for the app root, closest match winning. Canonicalise
    # first: the walk compares path strings, and a relative $subdir turns into
    # a chain of '..' segments that no longer matches anything useful.
    my $subdir       = $location->realpath;
    my $subdir_found = 0;

    #maximum of 10 iterations, to prevent infinite loop
    for ( 1 .. 10 ) {
        if ( _is_app_root($subdir) ) {
            $subdir_found = 1;
            last;
        }

        # stop at the volume root, where parent() is its own fixed point
        my $parent = $subdir->parent;
        last if $parent->stringify eq $subdir->stringify;

        $subdir = $parent;
    }

    my $path = $subdir_found ? $subdir : $location;

    # convert relative to absolute
    return $path->realpath->stringify;
}

1;
