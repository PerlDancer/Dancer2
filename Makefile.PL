
use strict;
use warnings;

use ExtUtils::MakeMaker 6.30;

my %WriteMakefileArgs = (
  'ABSTRACT'           => 'Core libraries for Dancer 2.0',
  'AUTHOR'             => 'Dancer Core Developers',
  'BUILD_REQUIRES'     => {
                           'File::Find' => '0',
                           'File::Temp' => '0',
                           'Test::More' => '0'
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
                           'Config::Any'  => '0',
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

    print STDERR "
WARNING ! This $0 file is provided just for lazy developers to
quickly build this module directly from source, and hack it. However this
module is managed by Dist::Zilla. Serious developers should install
Dist::Zilla, and issue 'dist help' to see how to build and develop it properly.
Especially, build/test/install requires are not properly set in this
file.

Contact the author if you need more help.

Now sleeping 10 secs so you get bored and go install Dist::Zilla :)\n\n";

    sleep 10;

WriteMakefile(%WriteMakefileArgs);



