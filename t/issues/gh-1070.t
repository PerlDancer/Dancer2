use strict;
use warnings;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;
    set show_errors => 1;
}

my $test = Plack::Test->create( App->to_app );

my $content =
  $test->request( GET '/nonexistent_path<strong>crazy</strong>' )->content;

like $content, qr{/nonexistent_path&lt;strong&gt;crazy&lt;/strong&gt;},
  "Escaped message";

unlike $content, qr{/nonexistent_path<strong>crazy</strong>},
  "No unescaped message";
