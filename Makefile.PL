
use strict;
use warnings;

use ExtUtils::MakeMaker 6.30;

my %WriteMakefileArgs = (
  'ABSTRACT'           => 'Core libraries for Dancer 2.0',
  'AUTHOR'             => 'Dancer Core Developers',
  'BUILD_REQUIRES'     => {
                           'File::Find' => '0',
                           'File::Temp' => '0',
                           'Test::More' => '0',
                           'HTTP::Body' => '0',
                           'HTTP::Server::Simple::PSGI' => '0',
                           'YAML' => '0',
                           'Template::Tiny' => '0',
                           'JSON' => '0',
                           'Capture::Tiny' => '0',
                           'indirect' => '0',
                           'multidimensional' => '0',
                           'bareword::filehandles' => '0',
                           'Plak::Request' => '0',
  },
  'CONFIGURE_REQUIRES' => {
                           'ExtUtils::MakeMaker' => '6.30'
  },
  'DISTNAME'           => 'Dancer-Core',
  'EXE_FILES'          => [],
  'LICENSE'            => 'perl',
  'NAME'               => 'Dancer::Core',
  'PREREQ_PM'          => {
                           'URI'          => '1.59',
                           'Carp'         => '0',
                           'Moo'          => '0',
                           'Scalar::Util' => '0',
                           'MIME::Types'  => '0',
  },
  'VERSION'            => '2.0',
  'test'               => {
                           'TESTS' => 't/*.t t/moo/*.t'
   },
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



