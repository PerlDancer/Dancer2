use strict;
use warnings;
use Test::More;

use File::Spec;
use File::Basename 'dirname';

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

my $views =
  File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), 'views'));

my $tt = engine('template');
isa_ok($tt, 'Dancer2::Template::TemplateToolkit');
is(
    $tt->default_tmpl_ext, 'foo',
    "Template extension is 'foo' as configured",
);

is(
    $tt->view('foo'),
    File::Spec->catfile($views, 'foo.foo'),
    "view('foo') gives filename with right extension as configured",
);

done_testing;
