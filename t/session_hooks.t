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
       session foo => 'bar'; #setting causes a session flush
	   return "ok";
    };
    get '/get_session' => sub {
      #this doesn't seem to work and returns undef! 
      is session->read('foo'), 'bar', "Got the right session back";	
    };
#   get '/flush_session' => sub {   }; #should I test flush separately ? It'll be a lot like set_session
    get '/destroy_session' => sub {
	  context->destroy_session;
    };

    #setup each hook again and test whether they return the correct type
    #there is unfortunately quite some duplication here.
    hook 'engine.session.before_create' => sub {
       my ($response) = @_;
       is ref($response), 'Dancer2::Core::Session', 'Correct response type returned in before_create';  
    };
	hook 'engine.session.after_create' => sub {
       my ($response) = @_;
       is ref($response), 'Dancer2::Core::Session', 'Correct response type returned in after_create';  
    };
    hook 'engine.session.before_retrieve' => sub {
       my ($response) = @_;
       is ref($response), 'Dancer2::Core::Session', 'Correct response type returned in before_retrieve';  
    };
    hook 'engine.session.before_retrieve' => sub {
       my ($response) = @_;
       is ref($response), 'Dancer2::Core::Session', 'Correct response type returned in before_retrieve';  
    };
}

#we'll now test our dancer app
use Dancer2::Test;

subtest 'session set' => sub {
    my $r = dancer_response get => '/set_session';
    is $test_flags->{'engine.session.before_create'}, 1, "session.before_create called";
    is $test_flags->{'engine.session.after_create'}, 1, "session.after_create called";
    is $test_flags->{'engine.session.before_flush'}, 1, "session.before_flush called";
    is $test_flags->{'engine.session.after_flush'}, 1, "session.after_flush called";

    is $test_flags->{'engine.session.before_retrieve'}, undef, "session.before_retrieve not called";
    is $test_flags->{'engine.session.after_retrieve'}, undef, "session.after_retrieve not called";
    is $test_flags->{'engine.session.before_destroy'}, undef, "session.before_destroy not called";
    is $test_flags->{'engine.session.after_destroy'}, undef, "session.after_destroy not called";
};

subtest 'session retrieve' => sub {
    my $r = dancer_response get => '/get_session';

#    is $test_flags->{'engine.session.before_retrieve'}, 1, "session.before_retrieve called";
#    is $test_flags->{'engine.session.after_retrieve'}, 1, "session.after_retrieve called";
    is $test_flags->{'engine.session.before_create'}, 2, "session.before_create not called";
    is $test_flags->{'engine.session.after_create'}, 2, "session.after_create not called";
    is $test_flags->{'engine.session.before_flush'}, 2, "session.before_flush not called";
    is $test_flags->{'engine.session.after_flush'}, 2, "session.after_flush not called";

    is $test_flags->{'engine.session.before_destroy'}, undef, "session.before_destroy not called";
    is $test_flags->{'engine.session.after_destroy'}, undef, "session.after_destroy not called";

};

# subtest 'session destroy' => sub {
#     my $r = dancer_response get => '/destroy_session';
#     is $test_flags->{'engine.session.before_destroy'}, 1, "session.before_destroy called";
#     is $test_flags->{'engine.session.after_destroy'}, 1, "session.after_destroy called";
# 
#     is $test_flags->{'engine.session.before_create'}, undef, "session.before_create not called";
#     is $test_flags->{'engine.session.after_create'}, undef, "session.after_create not called";
#     is $test_flags->{'engine.session.before_retrieve'}, undef, "session.before_retrieve not called";
#     is $test_flags->{'engine.session.after_retrieve'}, undef, "session.after_retrieve not called";
#     is $test_flags->{'engine.session.before_flush'}, undef, "session.before_flush not called";
#     is $test_flags->{'engine.session.after_flush'}, undef, "session.after_flush not called";
# };
done_testing;
