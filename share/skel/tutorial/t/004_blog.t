use strict;
use warnings;
use Test::More;
use Test::WWW::Mechanize::PSGI;

use [d2% appname %2d];
my $mech = Test::WWW::Mechanize::PSGI->new(
    app => [d2% appname %2d]->to_app,
);

subtest 'Landing page' => sub {
    $mech->get_ok('/', 'Got landing page');
    $mech->title_is('Danceyland Blog', '...for our blog');
    $mech->content_contains('Test Blog Post','...and it has a test post');
};

subtest 'Login' => sub {
    $mech->get_ok('/login', 'Visit login page to make some changes');
    $mech->submit_form_ok({
        fields => {
            username => 'admin',
            password => 'test',
        }}, '...so we give it a user');
};

subtest 'Create' => sub {
    $mech->get_ok('/create', 'Write a new blog post');
    $mech->submit_form_ok({
        fields => {
            title => 'Another Test Post',
            summary => 'Writing a blog post can be done by tests too',
            content => 'You can create blog entries programmatically with Perl!',
        }}, '...then write another post');
    $mech->base_like( qr</entry/\d+$>, '...and get redirected to the new entry' );
};

my $entry_id;
subtest 'Update' => sub {
    ($entry_id) = $mech->uri =~ m</(\d+)$>;
    $mech->get_ok("/update/$entry_id", 'Navigating to the update page for this post');
    $mech->submit_form_ok({
        fields => {
            title => 'Yet ANOTHER Test Post',
        }}, '...then update yet another post');
    $mech->base_like( qr</entry/${entry_id}$>, '...and get redirected to the entry page' );
    $mech->has_tag('h1','Yet ANOTHER Test Post', '...and it has the updated title');
};

subtest 'Delete' => sub {
    $mech->get_ok("/delete/$entry_id", "Go delete page for new entry");
    $mech->submit_form_ok({
        fields => {
            delete_it => 'yes',
        }}, '...then delete it!');
    $mech->get_ok("/entry/$entry_id", '...then try to navigate to the entry');
    $mech->content_contains('Invalid entry','...and see the post is no longer there');
};

done_testing;
