package App::Extra;
use Dancer2 'appname' => 'OtherApp';
use Dancer2::Plugin::Test::AccessDSL;

get '/' => sub {
    status(500);
    change_response_status();
    return 'OK';
};

1;
