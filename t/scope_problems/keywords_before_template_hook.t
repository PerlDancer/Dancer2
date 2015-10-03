use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common qw/GET/;
use File::Basename 'dirname';
use File::Spec;

my $views;
BEGIN {
  $views = File::Spec->rel2abs( File::Spec->catfile( dirname(__FILE__), 'views' ) );
}

eval { require Template; Template->import(); 1 }
    or plan skip_all => 'Template::Toolkit probably missing.';

{
    package Test::App;
    use Dancer2;

    set views => $views;
    set logger => 'Note';
    set template => 'template_toolkit';

    hook before_template_render => sub {
        my $tokens = shift;
        var some_var => 21;  # var can only be used in a route handler..
    };

    get '/' => sub {
        die "Yes yes YES!";
    };
}

my $test = Plack::Test->create(Test::App->to_app);

my $res = $test->request(GET '/');
is($res->code, 500, "Got 500 response");
like( $res->content, qr/This is a dummy error template/,
    "with the template content" );

done_testing;

