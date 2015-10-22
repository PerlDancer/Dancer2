use strict;
use warnings;
use Test::More;

eval { require Template; Template->import(); 1 }
  or plan skip_all => 'Template::Toolkit probably missing.';

use Dancer2;

set engines => {
    template => {
        template_toolkit => {
            extension => 'foo',
        },
    },
};
set template => 'template_toolkit';

my $tt = engine('template');
isa_ok( $tt, 'Dancer2::Template::TemplateToolkit' );
is( $tt->default_tmpl_ext, 'foo',
    "Template extension is 'foo' as configured",
);

is( $tt->view_pathname('foo'), 'foo.foo' ,
    "view('foo') gives filename with right extension as configured",
);

done_testing;
