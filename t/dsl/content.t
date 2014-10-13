#!perl

use strict;
use warnings;
use Test::More tests => 9;
use Plack::Test;
use HTTP::Request::Common;

{
    package App::SetContent;
    use Dancer2;
    get '/' => sub {
        content 'OK';

        'Not OK';
    };
}

{
    package App::PassSuccess;
    use Dancer2;

    get '/' => sub {
        content 'Missing';
        pass;
    };

    get '/' => sub {
        'There';
    };
}

{
    package App::PassFail;
    use Dancer2;

    get '/' => sub {
        content 'Missing';
        pass;
    };

    get '/' => sub {};
}

{
    my $app = App::SetContent->to_app;
    isa_ok( $app, 'CODE' );

    my $test = Plack::Test->create($app);
    my $res  = $test->request( GET '/' );

    is( $res->code,    200,  'Reached route'   );
    is( $res->content, 'OK', 'Correct content' );
}

{
    my $app = App::PassSuccess->to_app;
    isa_ok( $app, 'CODE' );

    my $test = Plack::Test->create($app);
    my $res  = $test->request( GET '/' );

    is( $res->code,    200,     'Reached route'   );
    is( $res->content, 'There', 'Correct content' );
}

{
    my $app = App::PassFail->to_app;
    isa_ok( $app, 'CODE' );

    my $test = Plack::Test->create($app);
    my $res  = $test->request( GET '/' );

    is( $res->code,    200, 'Reached route'   );
    is( $res->content, '',  'Correct content' );
}

