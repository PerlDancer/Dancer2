# alias profile='perl -d:NYTProf tools/perf.pl -- --profile && nytprofhtml'
# alias compare='perl tools/perf.pl -- --compare'
BEGIN { $INC{'Devel/NYTProf.pm'} && DB::disable_profile() } ## no critic
use strict;
use warnings;
use Plack::Test;
use HTTP::Request::Common;
use Dumbbench;
use Getopt::Long qw<:config no_ignore_case>;
use HTTP::XSHeaders;
use HTTP::XSCookies;

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

my $test_app1 = Plack::Test->create($app1);
my $test_app2 = Plack::Test->create($app2);
my $req = GET '/';

sub check_app {
    my ( $number, $app ) = @_;
    print STDERR "Checking Dancer $number... ";

    my $res = $app->request($req);
    if ( $res->content eq "ok$number" ) {
        print STDERR "Good!\n";
    } else {
        print STDERR "Bad!\n";
        die "App $app failed, exiting!\n";
    }
}

my %opts;
GetOptions(
    'profile'   => \$opts{'profile'},
    'bench'     => \$opts{'bench'},
    'compare'   => \$opts{'compare'},
    'speed|s=s' => \$opts{'speed'},
);

my $max = 1 . '0' x ( $opts{'speed'} || 3 );

if ( $opts{'profile'} ) {
    DB::enable_profile();
    $app2->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/',
    }) for 1 .. 50;
    DB::disable_profile();
    DB::finish_profile();
} elsif ( $opts{'compare'} ) {
    my $bench = Dumbbench->new(
        target_rel_precision => 0.005,
        initial_runs         => 20,
    );

    check_app( 1 => $test_app1 );
    check_app( 2 => $test_app2 );

    $bench->add_instances(
        Dumbbench::Instance::PerlSub->new(
            name => 'D1',
            code => sub {
                for ( 1 .. $max ) {
                    $test_app1->request($req);
                }
            },
        ),

        Dumbbench::Instance::PerlSub->new(
            name => 'D2',
            code => sub {
                for ( 1 .. $max ) {
                    $test_app2->request($req);
                }
            },
        ),
    );

    $bench->run;
    $bench->report;
} elsif ( $opts{'bench'} ) {
    my $bench = Dumbbench->new(
        target_rel_precision => 0.005,
        initial_runs         => 20,
    );

    my $test_app2 = Plack::Test->create($app2);
    my $req = GET '/';

    check_app( 2 => $test_app2 );

    $bench->add_instances(
        Dumbbench::Instance::PerlSub->new(
            name => 'D2',
            code => sub {
                for ( 1 .. $max ) {
                    $test_app2->request($req);
                }
            },
        ),
    );

    $bench->run;
    $bench->report;
} else {
    print << "_END_HELP";
$0 -- <-s | --speed 1|2|3|4|5> <profile | bench | compare>
("--" is required before parameters because D1 parses ARGV)

Commands:

    profile     Profile a single Dancer 2 request
                (perl -d:NYTProf tools/perf.pl -- --profile)
                You will need to run `nytprofhtml` manually afterwards

    bench       Benchmark a Dancer 2 request
                (perl tools/perf.pl -- --bench <--speed 1|2|3|4|5>)

    compare     Compare a Dancer 1 request and a Dancer 2 request
                (perl tools/perf.pl -- --compare <--speed 1|2|3|4|5>)

Options:

    --speed | -s    How many requests to run for each
                    (-s 5 == 1e5 == 100,000 times)

_END_HELP
}
