package t::lib::TestPod;
use Dancer2;

=head1 NAME

TestPod

=over

=cut

=item get "/in_testpod"

testpod

=cut

get '/in_testpod' => sub {
    session('test');
};

=back

=cut


1;
