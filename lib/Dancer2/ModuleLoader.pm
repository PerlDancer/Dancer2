package Dancer2::ModuleLoader;

# ABSTRACT: Dynamic module loading helpers for Dancer2 core components

use strict;
use warnings;

use Module::Runtime qw/ use_module /;

=head1 DESCRIPTION

Sometimes in Dancer2 core we need to use modules, but we don't want to declare
them all in advance in compile-time. These could be because the specific modules
provide extra features which depend on code that isn't (and shouldn't) be in
core, or perhaps because we only want these components loaded in lazy style,
saving loading time a bit.

To do such things takes a bit of code for localizing C<$@> and C<eval>ing. That
code has been refactored into this module to help Dancer2 core developers.

B<Please only use this for Dancer2 core modules>. If you're writing an external
Dancer2 module (L<Dancer2::Template::Tiny>, L<Dancer2::Session::Cookie>, etc.),
please simply "C<use ModuleYouNeed>" in your code and don't use this module.

WARNING, all the following methods are CLASS methods.

=method load

Runs a "C<use ModuleYouNeed>".

    use Dancer2::ModuleLoader;
    ...
    Dancer2::ModuleLoader->load('Something')
        or die "Couldn't load Something\n";

    # load version 5.0 or more
    Dancer2::ModuleLoader->load('Something', '5.0')
        or die "Couldn't load Something\n";

    # load version 5.0 or more
    my ($res, $error) = Dancer2::ModuleLoader->load('Something', '5.0');
    $res or die "Couldn't load Something : '$error'\n";

Takes in arguments the module name, and optionally the minimum version number required.

In scalar context, returns 1 if successful, 0 if not.
In list context, returns 1 if successful, C<(0, "error message")> if not.

If you need to give arguments to the loading module, please use the method C<load_with_params>

=cut

sub load {
    my ( $class, $module, $version ) = @_;

    $class->require( $module, $version );

    # normal 'use', can be done via require + import
    my ( $res, $error ) = $class->load_with_params($module);
    return wantarray ? ( $res, $error ) : $res;
}

=method require

Runs a "C<require ModuleYouNeed>".

    use Dancer2::ModuleLoader;
    ...
    Dancer2::ModuleLoader->require('Something')
        or die "Couldn't require Something\n";
    my ($res, $error) = Dancer2::ModuleLoader->require('Something');
    $res or die "Couldn't require Something : '$error'\n";

If you are unsure what you need (C<require> or C<load>), learn the differences
between C<require> and C<use>.

Takes in arguments the module name, and an optional version.

In scalar context, returns 1 if successful, 0 if not.
In list context, returns 1 if successful, C<(0, "error message")> if not.

=cut

sub require {
    my ( $class, $module, $version ) = @_;

    eval {
        defined $version
          ? use_module( $module, $version )
          : use_module($module);
    }
      or return wantarray ? ( 0, $@ ) : 0;

    return 1;
}

=method load_with_params

Runs a "C<use ModuleYouNeed qw(param1 param2 ...)>".

    use Dancer2::ModuleLoader;
    ...
    Dancer2::ModuleLoader->load('Something', qw(param1 param2) )
        or die "Couldn't load Something\n";

    my ($res, $error) = Dancer2::ModuleLoader->load('Something', @params);
    $res or die "Couldn't load Something : '$error'\n";

Takes in arguments the module name, and optionally parameters to pass to the import internal method.

In scalar context, returns 1 if successful, 0 if not.
In list context, returns 1 if successful, C<(0, "error message")> if not.

=cut

sub load_with_params {
    my ( $class, $module, @args ) = @_;
    my ( $res, $error ) = $class->require($module);
    $res or return wantarray ? ( 0, $error ) : 0;

    # From perlfunc : If no "import" method can be found then the call is
    # skipped, even if there is an AUTOLOAD method.
    if ( $module->can('import') ) {

        # bump Exporter Level to import symbols in the caller
        local $Exporter::ExportLevel = ( $Exporter::ExportLevel || 0 ) + 1;
        local $@;
        eval { $module->import(@args) };
        my $error = $@;
        $error and return wantarray ? ( 0, $error ) : 0;
    }
    return 1;
}

=method use_lib

Runs a "C<use lib qw(path1 path2)>" at run time instead of compile time.

    use Dancer2::ModuleLoader;
    ...
    Dancer2::ModuleLoader->use_lib('path1', @other_paths)
        or die "Couldn't perform use lib\n";

    my ($res, $error) = Dancer2::ModuleLoader->use_lib('path1', @other_paths);
    $res or die "Couldn't perform use lib : '$error'\n";

Takes in arguments a list of path to be prepended to C<@INC>, in a similar way
than C<use lib>. However, this is performed at run time, so the list of paths
can be generated and dynamic.

In scalar context, returns 1 if successful, 0 if not.
In list context, returns 1 if successful, C<(0, "error message")> if not.

=cut

sub use_lib {
    my ( $class, @args ) = @_;
    use lib;
    local $@;
    lib->import(@args);
    my $error = $@;
    $error and return wantarray ? ( 0, $error ) : 0;
    return 1;
}

1;

