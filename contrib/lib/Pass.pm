package contrib::lib::Pass;

use Dancer;

get '/flow' => sub {
    my $count = var('count') || 0;
    var count => $count + 1;
    pass;
};

get '/flow' => sub {
    my $count = var('count');
    var count => $count + 1;
    pass;
};

get '/flow' => sub {
    var('count');
};

1;
