package Dancer2::Core::Role::DSL;
# ABSTRACT: Role for DSL
$Dancer2::Core::Role::DSL::VERSION = '0.159002';
use Moo::Role;
use Dancer2::Core::Types;
use Carp 'croak';
use Scalar::Util qw();

with 'Dancer2::Core::Role::Hookable';

has app => ( is => 'ro', required => 1 );

has keywords => (
    is      => 'rw',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_dsl_keywords',
);

sub supported_hooks { }

sub _build_dsl_keywords {
    my ($self) = @_;
    $self->can('dsl_keywords')
      ? $self->dsl_keywords
      : {};
}

sub register {
    my ( $self, $keyword, $is_global ) = @_;
    my $keywords = $self->keywords;
    my $pkg = ref($self);
    $pkg =~ s/__WITH__.+$//;

    if ( exists $keywords->{$keyword} ) {
        my $reg_pkg = $keywords->{$keyword}{'pkg'};
        $reg_pkg =~ s/__WITH__.+$//;
        $reg_pkg eq $pkg and return;

        croak "[$pkg] Keyword $keyword already registered by $reg_pkg";
    }

    $keywords->{$keyword} = { is_global => $is_global, pkg => $pkg };
}

sub dsl { $_[0] }

# exports new symbol to caller
sub export_symbols_to {
    my ( $self, $caller, $args ) = @_;
    my $exports = $self->_construct_export_map($args);

    ## no critic
    foreach my $export ( keys %{$exports} ) {
        no strict 'refs'; ## no critic (TestingAndDebugging::ProhibitNoStrict)
        my $existing = *{"${caller}::${export}"}{CODE};

        next if defined $existing;

        *{"${caller}::${export}"} = $exports->{$export};
    }
    ## use critic

    return keys %{$exports};
}

# private

sub _compile_keyword {
    my ( $self, $keyword, $opts ) = @_;

    my $code = $opts->{is_global}
               ? sub { $self->$keyword(@_) }
               : sub {
            croak "Function '$keyword' must be called from a route handler"
                unless defined $Dancer2::Core::Route::REQUEST;

            $self->$keyword(@_)
        };

    return $self->_apply_prototype($code, $opts);
}

sub _apply_prototype {
    my ($self, $code, $opts) = @_;

    # set prototype if one is defined for the keyword. undef => no prototype
    my $prototype;
    exists $opts->{'prototype'} and $prototype = $opts->{'prototype'};
    return Scalar::Util::set_prototype( \&$code, $prototype );
}

sub _construct_export_map {
    my ( $self, $args ) = @_;
    my $keywords = $self->keywords;
    my %map;
    foreach my $keyword ( keys %$keywords ) {
        # check if the keyword were excluded from importation
        $args->{ '!' . $keyword } and next;
        $map{$keyword} = $self->_compile_keyword( $keyword, $keywords->{$keyword} );
    }
    return \%map;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Core::Role::DSL - Role for DSL

=head1 VERSION

version 0.159002

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
