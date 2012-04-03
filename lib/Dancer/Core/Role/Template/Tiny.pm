package Dancer::Core::Role::Template::Tiny;

#ABSTRACT: role for building flavors of Template::Tiny engines

use strict;
use warnings;
use Moo;
use Carp;
use Dancer::Moo::Types;
use Template::Tiny;
use Dancer::FileUtils 'read_file_content';

with 'Dancer::Core::Role::Template';

has engine => (
    is => 'rw',
    default => sub { Template::Tiny->new },
    isa => sub { ObjectOf('Template::Tiny', @_) },
);

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
