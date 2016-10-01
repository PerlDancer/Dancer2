package Dancer2::Core::Role::HasLocation;
# ABSTRACT: Role for application location "guessing"

use Moo::Role;
use Dancer2::Core::Types;
use Dancer2::FileUtils ();
use File::Spec;
use Sub::Quote 'quote_sub';

# the path to the caller script/app
# Note: to remove any ambiguity between the accessor for the
# 'caller' attribute and the core function caller(), explicitly
# specify we want the function 'CORE::caller' as the default for
# the attribute.
has caller => (
    is      => 'ro',
    isa     => Str,
    default => quote_sub( q{
        my ( $caller, $script ) = CORE::caller;
        $script = File::Spec->abs2rel( $script ) if File::Spec->file_name_is_absolute( $script );
        $script;
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
    my $location = Dancer2::FileUtils::dirname($script);

    #we try to find bin and lib
    my $subdir       = $location;
    my $subdir_found = 0;

    #maximum of 10 iterations, to prevent infinite loop
    for ( 1 .. 10 ) {

        #try to find libdir and bindir to determine the root of dancer app
        my $libdir = Dancer2::FileUtils::path( $subdir, 'lib' );
        my $bindir = Dancer2::FileUtils::path( $subdir, 'bin' );

        #try to find .dancer_app file to determine the root of dancer app
        my $dancerdir = Dancer2::FileUtils::path( $subdir, '.dancer' );

        # if one of them is found, keep that; but skip ./blib since both lib and bin exist
        # under it, but views and public do not.
        if (
            ( $subdir !~ m![\\/]blib[\\/]?$! && -d $libdir && -d $bindir ) ||
            ( -f $dancerdir )
        ) {
            $subdir_found = 1;
            last;
        }

        $subdir = Dancer2::FileUtils::path( $subdir, '..' ) || '.';
        last if File::Spec->rel2abs($subdir) eq File::Spec->rootdir;

    }

    my $path = $subdir_found ? $subdir : $location;

    # return if absolute
    File::Spec->file_name_is_absolute($path)
        and return $path;

    # convert relative to absolute
    return File::Spec->rel2abs($path);
}

1;
