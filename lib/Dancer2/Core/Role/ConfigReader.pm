# ABSTRACT: Config role for Dancer2 core objects
package Dancer2::Core::Role::ConfigReader;

use Moo::Role;

use File::Spec;
use Config::Any;
use Hash::Merge::Simple;
use Carp 'croak';
use Module::Runtime 'require_module';

use Dancer2::Core::Factory;
use Dancer2::Core;
use Dancer2::Core::Types;
use Dancer2::FileUtils 'path';

has config_location => (
    is      => 'ro',
    isa     => ReadableFilePath,
    lazy    => 1,
    default => sub { $ENV{DANCER_CONFDIR} || $_[0]->location },
);

# The type for this attribute is Str because we don't require
# an existing directory with configuration files for the
# environments.  An application without environments is still
# valid and works.
has environments_location => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    default => sub {
        $ENV{DANCER_ENVDIR}
          || File::Spec->catdir( $_[0]->config_location, 'environments' )
          || File::Spec->catdir( $_[0]->location,        'environments' );
    },
);

# It is required to get environment from the caller.
# Environment should be passed down from Dancer2::Core::App.
has environment => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

# It is required to get location from the caller.
has location => (
    is       => 'ro',
    isa      => ReadableFilePath,
    required => 1,
);

1;

__END__

=head1 DESCRIPTION

This is a redesigned Dancer2::Core::Role to manage
the Dancer2 configuration. Unlike earlier when config
was read from files at the start of the web app,
now config can be reread at a request. Also config is
not created at the time of reading the class.

This new behaviour makes it possible to attach plugins
via hooks to influence config reading.

It also becomes possible to reload configuration without
restarting the app.

Provides a C<config> attribute that - when accessing
the first time - feeds itself by finding and parsing
configuration files.

Also provides a C<setting()> method which is supposed to be used by externals to
read/write config entries.

=head1 ATTRIBUTES

=attr location

Absolute path to the directory where the server started.

=attr config_location

Gets the location from the configuration. Same as C<< $object->location >>.

=attr environments_location

Gets the directory where the environment files are stored.

=attr config

Returns the whole configuration.

=attr environments

Returns the name of the environment.

=head1 METHODS

=head2 read_config

Load the configuration.
Whatever source the config comes from, files, env vars, etc.
