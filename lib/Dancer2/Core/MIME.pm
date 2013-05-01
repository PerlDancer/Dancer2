# ABSTRACT: Class to ease manipulation of MIME types

package Dancer2::Core::MIME;

use strict;
use warnings;

use Moo;
use Dancer2::Core::Types;
use Carp 'croak';
use MIME::Types;

# Initialise MIME::Types at compile time, to ensure it's done before
# the fork in a preforking webserver like mod_perl or Starman. Not
# doing this leads to all MIME types being returned as "text/plain",
# as MIME::Types fails to load its mappings from the DATA handle. See
# t/04_static_file/003_mime_types_reinit.t and GH#136.
BEGIN {
    MIME::Types->new(only_complete => 1);
}

has mime_type => (
    is      => 'ro',
    isa     => InstanceOf ['MIME::Types'],
    default => sub { MIME::Types->new(only_complete => 1) },
    lazy    => 1,
);

has custom_types => (
    is      => 'rw',
    isa     => HashRef,
    default => sub { +{} },
);

has default => (
    is      => 'rw',
    isa     => Str,
    builder => "reset_default",
);

sub reset_default {
    my ($self) = @_;
    $self->default("application/data");
}

sub add_type {
    my ($self, $name, $type) = @_;
    $self->custom_types->{$name} = $type;
    return;
}

sub add_alias {
    my ($self, $alias, $orig) = @_;
    my $type = $self->for_name($orig);
    $self->add_type($alias, $type);
    return $type;
}

sub for_file {
    my ($self, $filename) = @_;
    my ($ext) = $filename =~ /\.([^.]+)$/;
    return $self->default unless $ext;
    return $self->for_name($ext);
}

sub name_or_type {
    my ($self, $name) = @_;

    return $name if $name =~ m{/};    # probably a mime type
    return $self->for_name($name);
}

sub for_name {
    my ($self, $name) = @_;
    return
         $self->custom_types->{lc $name}
      || $self->mime_type->mimeTypeOf(lc $name)
      || $self->default;
}

1;

__END__

=head1 SYNOPSIS

	use Dancer2::Core::MIME;

	my $mime = Dancer::MIME->new();

	# get mime type for an alias
	my $type = $mime->for_name('css');

	# set a new mime type
	my $type = $mime->add_type( foo => 'text/foo' );

	# set a mime type alias
	my $alias = $mime->add_alias( f => 'foo' );

	# get mime type for a file (based on extension)
	my $file = $mime->for_file( "foo.bar" );

	# set the $thing into a content $type.
	my $type = $mime->name_or_type($thing);


	# get current defined default mime type
	my $type = $mime->default;

	# set the default mime type using config.yml
	# or using the set keyword
	set default_mime_type => 'text/plain';

=head1 DESCRIPTION

Dancer::MIME initialises MIME::Types at compile time, to ensure it's done before
the fork in a preforking webserver like mod_perl or Starman. Not doing this
leads to all MIME types being returned as "text/plain", as MIME::Types fails to
load its mappings from the DATA handle.

=head1 ATTRIBUTES

=head2 mime_type

The mime_type which is found with MIME::Types.

=head2 custom_types

custom_types is the mime_type that defaults to the user defined mime_type.

=head2 default

default mime_type is the default defined MIME::Types.The default mime_type is
text/plain.

=head1 METHODS

=head2 reset_default

This method resets mime_type to the default type.

=head2 add_type

This method adds the new mime type.

=head2  add_alias

The add_alias sets a mime type alias.

=head2 for_name

The method for_name gets mime type for an alias.

=head2 for_file

This method gets mime type for a file based on extension.

=head2 name_or_type

This method sets the customized mime name or default mime type into a content
type.

