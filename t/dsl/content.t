use strict;
use warnings;
use Test::More tests => 6;
use Plack::Test;
use HTTP::Request::Common;

{
    package App::SetContent; ## no critic
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
    my $test = Plack::Test->create( App::SetContent->to_app );
    my $res  = $test->request( GET '/' );

    is( $res->code,    200,  'Reached route'   );
    is( $res->content, 'OK', 'Correct content' );
}

{
    my $test = Plack::Test->create( App::PassSuccess->to_app );
    my $res  = $test->request( GET '/' );

    is( $res->code,    200,     'Reached route'   );
    is( $res->content, 'There', 'Correct content' );
}

{
    my $test = Plack::Test->create( App::PassFail->to_app );
    my $res  = $test->request( GET '/' );

    is( $res->code,    200, 'Reached route'   );
    is( $res->content, '',  'Correct content' );
}
