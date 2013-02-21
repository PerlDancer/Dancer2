package MyDancerDSL;

use Moo;
use Dancer2::Core::Hook;
use Dancer2::Core::Error;
use Dancer2::FileUtils;
use Carp;

extends 'Dancer2::Core::DSL';

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

sub gateau { goto &Dancer2::Core::DSL::cookie }
sub moteur { goto &Dancer2::Core::DSL::engine }
sub stop   { goto &Dancer2::Core::DSL::halt }
sub prend  { goto &Dancer2::Core::DSL::get }
sub envoie { goto &Dancer2::Core::DSL::post }
sub entete { goto &Dancer2::Core::DSL::header }

1;
