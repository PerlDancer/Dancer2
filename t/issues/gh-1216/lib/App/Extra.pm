package App::Extra;
use Dancer2 appname => 'App';
use Dancer2::Plugin::Null;

get '/' => sub {'OK'};

1;
