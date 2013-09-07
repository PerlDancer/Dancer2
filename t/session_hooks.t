use strict;
use warnings;
use Test::More;

my @hooks_to_test = qw(
  engine.session.before_retrieve
  engine.session.after_retrieve

  engine.session.before_create
  engine.session.after_create

  engine.session.before_destroy
  engine.session.after_destroy

  engine.session.before_flush
  engine.session.after_flush
);

#we'll set a flag here when each hook is called. Then our test will then verify this
my $test_flags = {};

#we'll create a dancer app to test our hooks
{
    use Dancer2;
    
    #Can't think of a way to abstract this so that I can just 
    #change the backend and keep the same code for the tests
    set session => 'Simple';

    for my $hook (@hooks_to_test) {
        hook $hook => sub {
         $test_flags->{$hook} ||= 0;
         $test_flags->{$hook}++;
        }
    }

    get '/set_session' => sub {
       session->{foo} = 1;
       return 'ok';	 
    };

    hook 'engine.session.before_create' => sub {
       my ($response) = @_;
       is ref($response), 'Dancer2::Core::Session', 'Correct response type returned in before_create';  
    };
}

#we'll now test our dancer app
use Dancer2::Test;

subtest 'session create' => sub {
    my $r = dancer_response get => '/set_session';
    #is $r, "ok", "a session value "
    is $test_flags->{'engine.session.before_create'}, 1, "session.before_create called";
    is $test_flags->{'engine.session.after_create'}, 1, "session.after_create called";

};
done_testing;
