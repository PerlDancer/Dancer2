package Dancer2::Template::Tiny;
# ABSTRACT: Template::Tiny engine for Dancer2

use Moo;
use Carp qw/croak/;
use Path::Tiny ();
use Dancer2::Core::Types;
use Dancer2::Template::Implementation::ForkedTiny;

with 'Dancer2::Core::Role::Template';

has '+engine' => (
    isa => InstanceOf ['Dancer2::Template::Implementation::ForkedTiny']
);

sub _build_engine {
    Dancer2::Template::Implementation::ForkedTiny->new( %{ $_[0]->config } );
}

sub render {
    my ( $self, $template, $tokens ) = @_;

    ( ref $template || -f $template )
      or croak "$template is not a regular file or reference";

    my $template_data =
      ref $template
      ? ${$template}
      : Path::Tiny::path($template)->slurp_utf8;

    my $content;

    $self->engine->process( \$template_data, $tokens, \$content, )
      or die "Could not process template file '$template'";

    return $content;
}

1;

__END__

=head1 SYNOPSIS

This template engine allows you to use L<Template::Tiny> in L<Dancer2>.

L<Template::Tiny> is an implementation of a subset of L<Template::Toolkit> (the
major parts) which takes much less memory and is faster. If you're only using
the main functions of Template::Toolkit, you could use Template::Tiny. You can
also seamlessly move back to Template::Toolkit whenever you want.

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
even though L<Template::Tiny> doesn't really support it.

=method render($template, \%tokens)

Renders the template.  The first arg is a filename for the template file
or a reference to a string that contains the template.  The second arg
is a hashref for the tokens that you wish to pass to
L<Template::Toolkit> for rendering.

=head1 SEE ALSO

L<Dancer2>, L<Dancer2::Core::Role::Template>, L<Template::Tiny>,
L<Dancer2::Template::Implementation::ForkedTiny>.
