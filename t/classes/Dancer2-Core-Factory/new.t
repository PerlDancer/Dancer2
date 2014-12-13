use strict;
use warnings;
use Test::More tests => 5;

use_ok('Dancer2::Core::Factory');

my $factory = Dancer2::Core::Factory->new;
isa_ok( $factory, 'Dancer2::Core::Factory' );
can_ok( $factory, 'create' );

my $template = Dancer2::Core::Factory->create(
    'template', 'template_toolkit', layout => 'mylayout'
);

isa_ok( $template, 'Dancer2::Template::TemplateToolkit' );
is( $template->{'layout'}, 'mylayout', 'Correct layout set in the template' );
