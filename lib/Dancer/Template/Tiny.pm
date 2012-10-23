package Dancer::Template::Tiny;
# ABSTRACT: Template::Tiny engine for Dancer

use strict;
use warnings;
use Carp;
use Moo;
use Dancer::Core::Types;
use Template::Tiny;
use Dancer::FileUtils 'read_file_content';

with 'Dancer::Core::Role::Template';

=head1 SYNOPSIS

This template engine allows you to use L<Template::Tiny> in L<Dancer>.

L<Template::Tiny> is an implementation of a subset of L<Template::Toolkit> (the
major parts) which takes much less memory and is faster. If you're only using
the main functions of Template::Toolkit, you could use Template::Tiny. You can
also seemlessly move back to Template::Toolkit whenever you want.

You can read more on L<Template::Tiny>.

To use this engine, all you need to configure in your L<Dancer>'s
C<config.yaml>:

    template: "tiny"

Of course, you can also set this B<while> working using C<set>:

    # code code code
    set template => 'tiny';

Since L<Dancer> has internal support for a wrapper-like option with the
C<layout> configuration option, you can have a L<Template::Toolkit>-like WRAPPER
even though L<Template::Tiny> doesn't really support it. :)

=cut

has '+engine' => (
    isa => InstanceOf['Template::Tiny'],
);

sub _build_name   {'Tiny'}
sub _build_engine { Template::Tiny->new }

=method render

Renders the template. Accepts a string to a file or a reference to a string of
the template.

=cut

sub render {
    my ( $self, $template, $tokens ) = @_;

    ( ref $template || -f $template )
        or die "$template is not a regular file or reference";

    my $template_data = ref $template    ?
                            ${$template} :
                            read_file_content($template);

    my $content;

    $self->engine->process(
        \$template_data,
        $tokens,
        \$content,
    ) or die "Could not process template file '$template'";

    return $content;
}

1;


