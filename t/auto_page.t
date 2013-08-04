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
like $r->content, qr/---\nPage under folder/, '...with proper content';;

done_testing;
