package Dancer2::Core::Role::DSL;
# ABSTRACT: Role for DSL

use Moo::Role;
use Dancer2::Core::Types;
use Carp 'croak';

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

    foreach my $export ( keys %{$exports} ) {
        no strict 'refs'; ## no critic (TestingAndDebugging::ProhibitNoStrict)
        my $existing = *{"${caller}::${export}"}{CODE};

        next if defined $existing;

        *{"${caller}::${export}"} = $exports->{$export};
    }

    return keys %{$exports};
}

# private

sub _compile_keyword {
    my ( $self, $keyword, $opts ) = @_;

    ## no critic (BuiltinFunctions::ProhibitStringyEval)
    my $prototype     = $opts->{'prototype'} || '@';
    my $main_code     = qq{ \$self->$keyword(\@_); };
    my $compiled_code = $opts->{'is_global'}
        ? eval qq{
            sub($prototype) { $main_code }
        }
        : eval qq{
            sub($prototype) {
                \$self->app->has_request or
                  croak "Function '\$keyword' must be called from a route handler";
                $main_code
            }
        };
    ## use critic

    $@ and die "Cannot compile keyword $keyword: $@\n";

    return $compiled_code;
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
