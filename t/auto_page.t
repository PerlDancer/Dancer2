use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{
    package AutoPageTest;
    use Dancer2;

    set auto_page => 1;
    ## HACK HACK HACK
    Dancer2::Handler::AutoPage->register(app);
    engine('template')->views('t/views');
    engine('template')->layout('main');
}

my $app = Dancer2->runner->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    {
        my $r = $cb->( GET '/auto_page' );

        is( $r->code, 200, 'Autopage found the page' );
        like(
            $r->content,
            qr/---\nHey! This is Auto Page working/,
            '...with proper content',
        );
    }

    {
        my $r = $cb->( GET '/folder/page' );

        is( $r->code, 200, 'Autopage found the page under a folder' );
        like(
            $r->content,
            qr/---\nPage under folder/,
            '...with proper content',
        );
    }

    {
        my $r = $cb->( GET '/non_existent_page' );
        is( $r->code, 404, 'Autopage doesnt try to render nonexistent pages' );
    }

    {
        my $r = $cb->( GET '/file.txt' );
        is( $r->code, 200, 'found file on public with autopage' );
        is(
            $r->content,
            "this is a public file\n",
            '[GET /file.txt] Correct content',
        );

        like(
            $r->headers->content_type,
            qr{text/plain},
            'public served file as correct mime',
        );
    }

};

done_testing;
