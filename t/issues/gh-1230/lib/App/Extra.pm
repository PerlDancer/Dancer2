package App::Extra;
use Dancer2 'appname' => 'OtherApp';
use Dancer2::Plugin::Test::AccessPluginDSL;

get '/' => sub {
    status(500);
    test_change_response_status();
    return 'OK';
};

1;
