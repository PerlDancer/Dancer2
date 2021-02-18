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
    builder => '_build_location',
);

# FIXME: i hate you most of all -- Sawyer X
sub _build_location {
    my $self   = shift;
    my $script = $self->caller;

    # default to the dir that contains the script...
    my $location = Path::Tiny::path($script)->parent;

    $location->is_dir
        or Carp::croak("Caller $script is not an existing file");

    #we try to find bin and lib
    my $subdir       = $location;
    my $subdir_found = 0;

    #maximum of 10 iterations, to prevent infinite loop
    for ( 1 .. 10 ) {

        #try to find libdir and bindir to determine the root of dancer app
        my $libdir = $subdir->child('lib');
        my $bindir = $subdir->child('bin');

        #try to find .dancer_app file to determine the root of dancer app
        my $dancerdir = $subdir->child('.dancer');

        # if one of them is found, keep that; but skip ./blib since both lib and bin exist
        # under it, but views and public do not.
        if (
            ( $subdir !~ m![\\/]blib[\\/]?$! && $libdir->is_dir && $bindir->is_dir ) ||
            ( $dancerdir->is_file )
        ) {
            $subdir_found = 1;
            last;
        }

        $subdir = $subdir->parent;

        last if $subdir->realpath->stringify eq Path::Tiny->rootdir->stringify;
    }

    my $path = $subdir_found ? $subdir : $location;

    # convert relative to absolute
    return $path->realpath->stringify;
}

1;
