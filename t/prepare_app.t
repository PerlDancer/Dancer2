use strict;
use warnings;
use Plack::Test;
use HTTP::Request::Common;
use Test::More 'tests' => 2;
use Capture::Tiny qw< capture_stderr capture_merged >;

{
    package App;
    use Dancer2;
    sub prepare_app {1}
    get '/' => sub {'OK'};
}

{
    package Bar;
    use Dancer2 'appname' => 'App';
    sub prepare_app {2}
    get '/' => sub {'OK'};
}

my $msg = qr{
    ^ WARNING: \s You \s have \s a \s subroutine \s in \s your
    \s app \s called \s 'prepare_app' \.
    \s In \s the \s future \s this \s will \s automatically
    \s be \s called \s by \s Dancer2 \.
}xms;

subtest 'App' => sub {
    my $app;
    like(
        capture_stderr { $app = App->to_app; },
        $msg,
        'Got warning on prepare_app sub',
    );

    my $test = Plack::Test->create($app);
    my $res;
    my $out;
    capture_merged { $res = $test->request( GET '/' )->content },
    is(
        $res,
        'OK',
        'Correct content',
    );

    is( $out, undef, 'No extra warnings or output' );
};

subtest 'Bar' => sub {
    my $app;
    like(
        capture_stderr { $app = Bar->to_app; },
        $msg,
        'Got warning on prepare_app sub',
    );
};
