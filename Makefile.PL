
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Core libraries for Dancer 2.0",
  "AUTHOR" => "Dancer Core Developers",
  "BUILD_REQUIRES" => {
    "Capture::Tiny" => "0.12",
    "Module::Build" => "0.3601",
    "Template" => 0,
    "Test::More" => "0.92",
    "Test::Fatal" => 0,
    "YAML::Any" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30",
    "Module::Build" => "0.3601"
  },
  "DISTNAME" => "Dancer",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Dancer",
  "PREREQ_PM" => {
    "Config::Any" => 0,
    "HTTP::Body" => 0,
    "HTTP::Server::Simple::PSGI" => 0,
    "JSON" => 0,
    "MIME::Types" => 0,
    "Moo" => "0.009014",
    "MooX::Types::MooseLike" => "0.15",
    "Plack::Request" => 0,
    "Template::Tiny" => 0
  },
  "VERSION" => "2.0",
  "test" => {
    "TESTS" => "t/*.t t/moo/*.t t/roles/*.t"
  }
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



