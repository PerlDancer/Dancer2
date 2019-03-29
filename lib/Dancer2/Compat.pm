package Dancer2::Compat;
# ABSTRACT: Compatibilty wrappers for newer module functions

use strict;
use warnings;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    encode_base64url
    pairgrep
    pairmap
);

sub import {
    my $self = shift;

    # This function is basically a dispatch table that executes
    # an anonymous sub for each matching import requested. Within
    # each sub an attempt is made to require and import the
    # wrapped function - and if the import fails (because the
    # function doens't exist), a wrapper version will be shimmed
    # into the symbol table and exported as normal. The only change
    # required on the caller's end is to use this module rather than
    # the original module being wrapped.

    {
        # MIME::Base64::encode_base64url (3.11+)
        encode_base64url => sub {
            require MIME::Base64;
            eval  { MIME::Base64->import('encode_base64url') };
            return unless ($@);

            *encode_base64url = sub {
                my $e = MIME::Base64::encode_base64(shift, "");
                   $e =~ s/=+\z//;
                   $e =~ tr[+/][-_];
                return $e;
            };
        },

        # List::Util::pairmap (1.29+)
        pairmap => sub {
            require List::Util;
            eval  { List::Util->import('pairmap') };
            return unless ($@);

            *pairmap = sub(&@) {
                my $code = shift;
                my $caller = caller;

                # Localize $a and $b
                no strict 'refs';
                local *{"${caller}::a"} = \my $a;
                local *{"${caller}::b"} = \my $b;

                # Generate array of pairs
                my @pairs;
                while (my @tmp = splice(@_, 0, 2)) { push @pairs, \@tmp }

                return map { ($a, $b) = @$_; &$code } @pairs;
            };
        },

        # List::Util::pairgrep (1.29+)
        pairgrep => sub {
            require List::Util;
            eval  { List::Util->import('pairgrep') };
            return unless ($@);

            *pairgrep = sub(&@) {
                my $code = shift;
                my $caller = caller;

                # Localize $a and $b
                no strict 'refs';
                local *{"${caller}::a"} = \my $a;
                local *{"${caller}::b"} = \my $b;

                # Generate array of pairs
                my @pairs;
                while (my @tmp = splice(@_, 0, 2)) { push @pairs, \@tmp }

                # In scalar context return the count of matching *pairs*
                my @res = grep { ($a, $b) = @$_; &$code } @pairs;
                return wantarray ? map @$_, @res : scalar @res;
            };
        },

    }->{$_}() foreach (@_);

    # Use Exporter's export_to_level method since this is a custom import
    # method and hence Exporter's inherited import method cannot be used.
    __PACKAGE__->export_to_level(1, $self, @_);
}

1;

__END__

=func encode_base64url

Compatibility wrapper for MIME::Base64::encode_base64url

=func pairmap

Compatibility wrapper for List::Util::pairmap

=func pairgrep

Compatibility wrapper for List::Util::pairgrep

=cut
