package Dancer2::Template::TemplateToolkitFoo;

# Custom Template::Toolkit template engine that uses a custom Template class

use strict;
use warnings;

use Moo;
use TemplateFoo;

extends 'Dancer2::Template::TemplateToolkit';

has '+template_class' => ( default => 'TemplateFoo' );

1;
