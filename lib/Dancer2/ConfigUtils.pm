package Dancer2::ConfigUtils;
# ABSTRACT: Config utility helpers

use strict;
use warnings;

use Carp;
use Module::Runtime qw{ require_module };

use Exporter 'import';
our @EXPORT_OK = qw(
    normalize_config_entry
);

my $NORMALIZERS = {
    charset => sub {
        my ($charset) = @_;
        return $charset if !length( $charset || '' );

        require_module('Encode');
        my $encoding = Encode::find_encoding($charset);
        croak
          "Charset defined in configuration is wrong : couldn't identify '$charset'"
          unless defined $encoding;
        my $name = $encoding->name;

        # Perl makes a distinction between the usual perl utf8, and the strict
        # utf8 charset. But we don't want to make this distinction
        $name = 'utf-8' if $name eq 'utf-8-strict';
        return $name;
    },
};

sub normalize_config_entry {
    my ( $name, $value ) = @_;
    $value = $NORMALIZERS->{$name}->($value)
      if exists $NORMALIZERS->{$name};
    return $value;
}

1;
