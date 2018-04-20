use Dancer2;
 
get '/' => sub {
    return 'Hello World';
};
 
__PACKAGE__->to_app;
