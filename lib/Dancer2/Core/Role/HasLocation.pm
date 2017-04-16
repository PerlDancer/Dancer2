package Dancer2::Core::Role::HasLocation;
# ABSTRACT: Role for application location "guessing"

use Moo::Role;
use Dancer2::Core::Types;
use Dancer2::FileUtils;
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
    # return if absolute
    File::Spec->file_name_is_absolute($location)
        and return $location;

    # convert relative to absolute
    return File::Spec->rel2abs($location);
}

1;
