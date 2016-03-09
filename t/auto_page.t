use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{
    package AutoPageTest;
    use Dancer2;

    set auto_page => 1;
    set views     => 't/views';
    set layout    => 'main';
    set charset   => 'UTF-8';
}


my @engines = ('tiny');
eval {require Template; Template->import(); push @engines, 'template_toolkit';};

for my $tt_engine ( @engines ) {
    # Change template engine and run tests
    AutoPageTest::set( template => $tt_engine );
    subtest "autopage with template $tt_engine" => \&run_tests;
}

sub run_tests {
    my $test = Plack::Test->create( AutoPageTest->to_app );

    {
        my $r = $test->request( GET '/auto_page' );

        is( $r->code, 200, 'Autopage found the page' );
        # ö is U+00F6 or c3 b6 when encoded as bytes
        like(
            $r->content,
            qr/---\nHey! This is Auto Page w\x{c3}\x{b6}rking/,
            '...with proper content',
        );

        is(
            $r->headers->content_type,
            'text/html',
            'auto page has correct content type header',
        );

        is(
            $r->headers->content_type_charset,
            'UTF-8',
            'auto page has correct charset in content type header',
        );

        is(
            $r->headers->content_length,
            98, # auto_page.tt+layouts/main.tt processed. ö has two bytes in UTF-8
            'auto page has correct content length header',
        );
    }

    {
        my $r = $test->request( GET '/folder/page' );

        is( $r->code, 200, 'Autopage found the page under a folder' );
        like(
            $r->content,
            qr/---\nPage under folder/,
            '...with proper content',
        );
    }

    {
        my $r = $test->request( GET '/non_existent_page' );
        is( $r->code, 404, 'Autopage doesn\'t try to render nonexistent pages' );
    }

    {
        my $r = $test->request( GET '/layouts/main');
        is( $r->code, 404, 'Layouts are not served' );
    }

    {
        my $r = $test->request( GET '/file.txt' );
        is( $r->code, 200, 'found file on public with autopage' );
        is(
            $r->content,
            "this is a public file\n",
            '[GET /file.txt] Correct content',
        );

        like(
            $r->headers->content_type,
            qr{text/plain},
            'public served file has correct content type header',
        );
    }
}

done_testing;
