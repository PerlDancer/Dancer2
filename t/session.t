use Test::More;
use strict;
use warnings;

subtest yaml_session_as_object => sub {
    use File::Spec;
    use File::Basename 'dirname';
    use Dancer::Session::YAML;

    my $dir =
      File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), 'sessions'));
    my $s = Dancer::Session::YAML->new(session_dir => $dir);

    ok(-d $dir, 'session dir is created');
    isnt $s->id, '', 'session id is set';

    my $id = $s->id;
    my $file = File::Spec->catfile($dir, "$id.yml");

    $s->write('foo' => 42);
    is($s->read('foo'), 42, 'read');

    ok($s->flush, 'flush session');
    ok(-r $file,  'session file is created');

    my $s2 = $s->retrieve($id);

    is_deeply $s2, $s, "session retrieved with id $id";

    is($s2->read('foo'), 42, 'read');

# cleanup
    unlink $file or die "unable to rm $file : $!";
    rmdir $dir   or die "unable to rmdir $dir : $!";
};

subtest simple_session_as_dsl => sub {

    use Dancer;
    use Dancer::Test;
    set session => 'Simple';

    get '/read' => sub { session('user') };
    get '/write/:value' => sub { session user => param('value') };

    my $r = dancer_response GET => '/read';
    is $r->content, '';

    $r = dancer_response GET => '/write/42';
    is $r->content, '42';

    $r = dancer_response GET => '/read';
    is $r->content, '42';
    
    $r = dancer_response GET => '/write/sukria';
    is $r->content, 'sukria';

    $r = dancer_response GET => '/read';
    is $r->content, 'sukria';

};
done_testing;
