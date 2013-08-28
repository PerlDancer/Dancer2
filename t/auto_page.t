use strict;
use warnings;

use Test::More;

{
    package AutoPageTest;
    use Dancer2;

    set auto_page => 1;
    ## HACK HACK HACK
    Dancer2::Handler::AutoPage->register(app);
    engine('template')->views('t/views');
    engine('template')->layout('main');

}

use Dancer2::Test apps => ['AutoPageTest'];

my $r = dancer_response GET => '/auto_page';

is $r->status, 200, 'Autopage found the page';
like $r->content, qr/---\nHey! This is Auto Page working/, '...with proper content';

$r = dancer_response GET => '/folder/page';

is $r->status, 200, 'Autopage found the page under a folder';
like $r->content, qr/---\nPage under folder/, '...with proper content';

$r = dancer_response GET => '/non_existent_page';
is $r->status, 404, 'Autopage doesnt try to render nonexistent pages';

$r = dancer_response GET => '/file.txt';
is $r->status, 200, 'Found file on public with Autopage';

like $r->headers->{'content-type'}, qr!text/plain!, "Public served file as correct mime";

done_testing;
