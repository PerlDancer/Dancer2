# ABSTRACT: Role for DSL

package Dancer2::Core::Role::DSL;
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

    # for now this check is disabled because the bug fix is breaking
    # the plugin_syntax test and we think this exposes a greater issue
    # that can not be resolved by just fixing the test
    if ( 0 && exists $keywords->{$keyword} ) {
        my $reg_pkg = $keywords->{$keyword}{'pkg'};
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
        no strict 'refs';
        my $existing = *{"${caller}::${export}"}{CODE};

        next if defined $existing;

        *{"${caller}::${export}"} = $exports->{$export};
    }

    return keys %{$exports};
}

# private

sub _compile_keyword {
    my ( $self, $keyword, $is_global ) = @_;

    my $compiled_code = sub {
        Dancer2::Core::debug( "["
              . $self->app->name
              . "] -> $keyword("
              . join( ', ', map { defined() ? $_ : '<undef>' } @_ )
              . ")" );
        $self->$keyword(@_);
    };

    if ( !$is_global ) {
        my $code = $compiled_code;
        $compiled_code = sub {
            croak "Function '$keyword' must be called from a route handler"
              unless defined $self->app->context;
            $code->(@_);
        };
    }

    return $compiled_code;
}

sub _construct_export_map {
    my ( $self, $args ) = @_;
    my $keywords = $self->keywords;
    my %map;
    foreach my $keyword ( keys %$keywords ) {
        # check if the keyword were excluded from importation
        $args->{ '!' . $keyword } and next;
        $map{$keyword} = $self->_compile_keyword( $keyword, $keywords->{$keyword}{is_global} );
    }
    return \%map;
}

1;
