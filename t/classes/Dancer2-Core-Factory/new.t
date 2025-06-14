use strict;
use warnings;
use Test::More tests => 7;

use_ok('Dancer2::Core::Factory');

my $factory = Dancer2::Core::Factory->new;
isa_ok( $factory, 'Dancer2::Core::Factory' );
can_ok( $factory, 'create' );

for my $class ('template_toolkit', '+Dancer2::Template::TemplateToolkit') {

    my $template = Dancer2::Core::Factory->create(
        'template', $class, layout => 'mylayout'
    );

    isa_ok( $template, 'Dancer2::Template::TemplateToolkit' );
    is( $template->{'layout'}, 'mylayout', 'Correct layout set in the template' );
}

