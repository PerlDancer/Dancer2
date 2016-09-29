package [% appname %];
use utf8;
use Dancer2;

our $VERSION = '0.1';

get '/' => sub {
    template 'index';
};

true;
