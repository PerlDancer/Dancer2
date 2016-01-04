package Dancer2::Core;
# ABSTRACT: Core libraries for Dancer2 2.0

use strict;
use warnings;

# Try to load all the modules for which we have specific version
# requirements.  We do installation time checks in dist.ini, but
# we need to back that up with runtime checks in case cpan/cpanm
# upgrades a platform Perl module, then a subsequent platform
# Perl package upgrade downgrades those modules to their prior
# versions.
#
# We say qw() to disable all auto-imports since we do not actually
# use any of these modules here.
use Exporter v5.570 qw();
use MIME::Base64 v3.130 qw();
use Moo v2.0.0 qw();
use Plack v1.3.500 qw();
use YAML v0.980 qw();


sub camelize {
    my ($value) = @_;

    my $camelized = '';
    for my $word ( split /_/, $value ) {
        $camelized .= ucfirst($word);
    }
    return $camelized;
}


1;

__END__

=func camelize

Camelize a underscore-separated-string.

=cut
