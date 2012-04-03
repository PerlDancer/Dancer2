package Dancer::Template::Simple;

use strict;
use warnings;
use Moo;

with 'Dancer::Core::Role::Template::Tiny';

# we process coderefs in the tokens
around render => sub {
    my $orig = shift;
    my ($self, $template, $tokens) = @_;

    for my $key (keys %{ $tokens }) {
        my $val = $tokens->{$key};

        if (ref($val) && ref($val) eq 'CODE') {
            # shouldn't we let the exception go?
            # Dancer 1 did that, so we do it the same
            local $@;
            eval { $val = $val->() };
            $val = "" if $@; 
            $tokens->{$key} = $val;
        }
    }

    $self->$orig($template, $tokens);
};

1;



