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
        like(
            $r->content,
            qr/---\nHey! This is Auto Page working/,
            '...with proper content',
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
            'public served file as correct mime',
        );
    }
}

done_testing;
