#PODNAME: plugins auto tests
#ABSTRACT: Test all Dancer plugins for Dancer 1 and 2

=head1 DESCRIPTION

plugins auto tests is a make script which tests all Dancer plugins on CPAN 
for both Dancer1 and Dancer2 and creates a report. plugins auto tests will
install perl and perl modules in the directory 'plugins_auto_test/perlbrew', 
i.e. it leaves your system installation untouched.

=head2 DEPENDENCIES

This tool depends on a number tools that are often installed on *nix, 
including make and perlbrew. It also requires an Internet connection to 
contact CPAN.

=head1 SYNOPSIS

   $ cd plugins_auto_test
   $ make 
   #report will be in plugins_auto_test/result.csv



