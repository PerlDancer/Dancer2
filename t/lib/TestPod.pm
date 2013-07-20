package t::lib::TestPod;
use Dancer2;

=head1 NAME

TestPod

=head2 ROUTES

=over

=cut

=item get "/in_testpod"

testpod

=cut

get '/in_testpod' => sub {

    # code;
};

=item get "/hello"

testpod

=cut

get '/hello' => sub {

    # code;
};

=item post '/in_testpod/*'

post in_testpod

=cut

post '/in_testpod/*' => sub {
    return 'post in_testpod';
};

=back

=head2 SPECIALS

=head3 PUBLIC

=over

=item get "/me:id"

=cut

get "/me:id" => sub {

    # code;
};

=back

=head3 PRIVAT

=over

=item post "/me:id"

post /me:id

=cut

post "/me:id" => sub {

    # code;
};

=back

=cut


1;
