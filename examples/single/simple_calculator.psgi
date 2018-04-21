use Dancer2;
 
get '/' => sub {
    return q{Welcome to simple calculator, powered by Dancer2.
     <a href="/add/2/3">add 2 + 3</a>
     <a href="/multiply?x=2&y=3">multiply</a>
     <form method="POST" action="/division">
     <input name="x"><input name="y">
     <input type="submit" value="Division">
     </form>
};
};
 

get '/add/:x/:y' => sub {
    my $x = route_parameters->{'x'};
    my $y = route_parameters->{'y'};

    return ($x+$y);
};

get '/multiply' => sub {
    my $x = query_parameters->{'x'};
    my $y = query_parameters->{'y'};

    return ($x*$y);
};

post '/division' => sub {       
    my $x = body_parameters->{'x'};
    my $y = body_parameters->{'y'};

    return int($x/$y);            
};              
               
__PACKAGE__->to_app;
