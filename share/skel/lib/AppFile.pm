package [d2% appname %2d];
use Dancer2;

our $VERSION = '0.1';

get '/' => sub {
    template 'index';
};

true;
