package TemplateFoo;

# Custom Template::Toolkit class

use base 'Template';

sub process
{   my ($self, $template, $vars, $outstream, @opts) = @_;
    $$outstream = "Custom Render Template";
    1;
}

1;
