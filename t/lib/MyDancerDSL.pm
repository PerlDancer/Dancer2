package MyDancerDSL;

use Moo;
use Dancer::Core::Hook;
use Dancer::Core::Error;
use Dancer::FileUtils;
use Carp;

extends 'Dancer::Core::DSL';

around dsl_keywords => sub {
    my $orig     = shift;
    my $keywords = $orig->(@_);

    push @$keywords, [gateau => 0],    # cookie
      [moteur => 1],                   # engine
      [stop   => 0],                   # halt
      [prend  => 1],                   # post
      [envoie => 1],                   # post
      [entete => 0];                   #header

    return $keywords;
};

sub gateau { goto &Dancer::Core::DSL::cookie }
sub moteur { goto &Dancer::Core::DSL::engine }
sub stop   { goto &Dancer::Core::DSL::halt }
sub prend  { goto &Dancer::Core::DSL::get }
sub envoie { goto &Dancer::Core::DSL::post }
sub entete { goto &Dancer::Core::DSL::header }

1;
