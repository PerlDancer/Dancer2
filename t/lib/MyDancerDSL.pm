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

    $keywords->{gateau} = { is_global => 0 }; # cookie
    $keywords->{moteur} = { is_global => 1 }; # engine
    $keywords->{stop}   = { is_global => 0 }; # halt
    $keywords->{prend}  = { is_global => 1 }; # post
    $keywords->{envoie} = { is_global => 1 }; # post
    $keywords->{entete} = { is_global => 0 }; #header

    return $keywords;
};

sub gateau { goto &Dancer2::Core::DSL::cookie }
sub moteur { goto &Dancer2::Core::DSL::engine }
sub stop   { goto &Dancer2::Core::DSL::halt }
sub prend  { goto &Dancer2::Core::DSL::get }
sub envoie { goto &Dancer2::Core::DSL::post }
sub entete { goto &Dancer2::Core::DSL::header }

1;
