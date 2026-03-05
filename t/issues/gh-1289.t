use strict;
use warnings;
use Test::More tests => 1;
use Plack::Test;
use HTTP::Request::Common;

{

    package App;
    use Dancer2;

    post '/forwards' => sub {
        forward('/still_contains_uploads');
    };

    any '/still_contains_uploads' => sub {
        my $upload = request->upload('testupload');
        if ($upload) {
            return;
        }
        die 'failed';
    };
}

{
    my $test = Plack::Test->create(App->to_app);

    my $response = $test->request(
        POST(
            '/forwards',
            Content_Type => 'form-data',
            Content =>
              [testupload => [undef, 'testupload', Content => "testcontent"]]
        )
    );

    is($response->code, 200, 'Uploads survive forward');
}

done_testing();
