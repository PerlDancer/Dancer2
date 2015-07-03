BEGIN { $INC{'Devel/NYTProf.pm'} && DB::disable_profile() } ## no critic
use strict;
use warnings;
use Plack::Test;
use HTTP::Request::Common;
use Dumbbench;

$ENV{'DANCER_ENVIRONMENT'} = 'production';
$ENV{'PLACK_ENV'} = 'production';

{
    package App::D1; ## no critic
    use Dancer;
    get '/' => sub {'ok1'};
}

{
    package App::D2; ## no critic
    use lib 'lib';
    use Dancer2;
    get '/' => sub {'ok2'};
}

my $app1 = App::D1::dance;
my $app2 = App::D2->to_app;

# run through lazily-loaded stuff
$app1->({
    REQUEST_METHOD => 'GET',
    PATH_INFO      => '/',
});

$app2->({
    REQUEST_METHOD => 'GET',
    PATH_INFO      => '/',
});

my $command = $ARGV[0]
    or die "$0 <profile | bench | compare>\n";

if ( $command eq 'profile' ) {
    DB::enable_profile();
    $app2->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/',
    });
    DB::disable_profile();
    DB::finish_profile();
} elsif ( $command eq 'compare' ) {
    my $bench = Dumbbench->new(
        target_rel_precision => 0.005,
        initial_runs         => 20,
    );

    my $test_app1 = Plack::Test->create($app1);
    my $test_app2 = Plack::Test->create($app2);
    my $req = GET '/';

    print $test_app1->request($req)->content, "\n";
    print $test_app2->request($req)->content, "\n";

    $bench->add_instances(
        Dumbbench::Instance::PerlSub->new(
            name => 'D1',
            code => sub {
                for ( 1 .. 1e3 ) {
                    $test_app1->request($req);
                }
            },
        ),

        Dumbbench::Instance::PerlSub->new(
            name => 'D2',
            code => sub {
                for ( 1 .. 1e3 ) {
                    $test_app2->request($req);
                }
            },
        ),
    );

    $bench->run;
    $bench->report;
} elsif ( $command eq 'bench' ) {
    my $bench = Dumbbench->new(
        target_rel_precision => 0.005,
        initial_runs         => 20,
    );

    my $test_app2 = Plack::Test->create($app2);
    my $req = GET '/';

    print $test_app2->request($req)->content, "\n";

    $bench->add_instances(
        Dumbbench::Instance::PerlSub->new(
            name => 'D2',
            code => sub {
                for ( 1 .. 1e3 ) {
                    $test_app2->request($req);
                }
            },
        ),
    );

    $bench->run;
    $bench->report;
} else {
    die "$0 <profile | bench | compare>\n";
}
