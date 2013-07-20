package Dancer2::Template::Tiny;

# ABSTRACT: Template::Tiny engine for Dancer2

use strict;
use warnings;
use Carp;
use Moo;
use Dancer2::Core::Types;
use Dancer2::Template::Implementation::ForkedTiny;
use Dancer2::FileUtils 'read_file_content';

with 'Dancer2::Core::Role::Template';

=head1 SYNOPSIS

This template engine allows you to use L<Template::Tiny> in L<Dancer2>.

L<Template::Tiny> is an implementation of a subset of L<Template::Toolkit> (the
major parts) which takes much less memory and is faster. If you're only using
the main functions of Template::Toolkit, you could use Template::Tiny. You can
also seemlessly move back to Template::Toolkit whenever you want.

However, Dancer2 uses a modified version of L<Template::Tiny>, which is L<Dancer2::Template::Implementation::ForkedTiny>. It adds 2 features :

=over

=item *

opening and closing tag are now configurable

=item *

CodeRefs are evaluated and their results is inserted in the result.

=back

You can read more on L<Dancer2::Template::Implementation::ForkedTiny>.

To use this engine, all you need to configure in your L<Dancer2>'s
C<config.yaml>:

    template: "tiny"

Of course, you can also set this B<while> working using C<set>:

    # code code code
    set template => 'tiny';

Since L<Dancer2> has internal support for a wrapper-like option with the
C<layout> configuration option, you can have a L<Template::Toolkit>-like WRAPPER
even though L<Template::Tiny> doesn't really support it. :)

=cut

has '+engine' =>
  ( isa => InstanceOf ['Dancer2::Template::Implementation::ForkedTiny'], );

sub _build_engine {
    Dancer2::Template::Implementation::ForkedTiny->new( %{ $_[0]->config } );
}

=method render

Renders the template. Accepts a string to a file or a reference to a string of
the template.

=cut

sub render {
    my ( $self, $template, $tokens ) = @_;

    ( ref $template || -f $template )
      or die "$template is not a regular file or reference";

    my $template_data =
      ref $template
      ? ${$template}
      : read_file_content($template);

    my $content;

    $self->engine->process( \$template_data, $tokens, \$content, )
      or die "Could not process template file '$template'";

    return $content;
}

1;


