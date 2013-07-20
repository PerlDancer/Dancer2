#!/usr/bin/env perl
#PODNAME: get_modules_list.pl
#ABSTRACT: List more or less all Dancer plugins on CPAN
use Modern::Perl;
use Data::Dumper;
use LWP::Simple;
use FindBin qw($Bin);
use ElasticSearch;

=head1 DESCRIPTION

lists CPAN modules (via api.metacpan.org) which depend on Dancer and have
plugin in the package name.

=head1 SYNOPSIS

	get_modules_list.pl 

=cut


my $es = ElasticSearch->new( servers => 'api.metacpan.org', no_refresh => 1 );

my $scroller = $es->scrolled_search(
    query       => { match_all => {} },
    search_type => 'scan',
    scroll      => '5m',
    index       => 'v0',
    type        => 'release',
    size        => 100,
    filter      => {
        term => {
            'release.dependency.module' => 'Dancer'
        }
    },

);

my $result = $scroller->next;

my %plugins;
while ( my $result = $scroller->next ) {
    $result->{_source}->{name} =~ /Dancer-Plugin/
      or next;
    my $name = $result->{_source}->{name};
    $name =~ s/-\d.*//;
    $name =~ s/-/::/g;
    $plugins{$name} = 1;
}
say $_ foreach sort keys %plugins;

