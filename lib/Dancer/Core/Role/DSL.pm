# Abstract: TODO

package Dancer::Core::Role::DSL;
use Moo::Role;
use Dancer::Moo::Types;
use Carp 'croak';

with 'Dancer::Core::Role::Hookable';

has app => (is => 'ro', required => 1);

has keywords => (
    is => 'rw',
    isa => sub { ArrayRef(@_) },
    lazy => 1,
    builder => '_build_dsl_keywords',
);

sub supported_hooks { }

sub _build_dsl_keywords {
    my ($self) = @_;
    $self->can('dsl_keywords')
        ? $self->dsl_keywords
        : [ ] ;
}

sub register {
    my ($self, $keyword, $is_global) = @_;
    
    grep { /^$keyword$/ } @{$self->keywords} 
        and croak "Keyword '$keyword' is not available.";

    push @{$self->keywords}, [ $keyword, $is_global ];
}

# exports new symbol to caller
sub export_symbols_to {
    my ($self, $caller) = @_;

    my $exports = $self->_construct_export_map;

    foreach my $export (keys %{ $exports }) {
        no strict 'refs';
        my $existing = *{"${caller}::${export}"}{CODE};
        *{"${caller}::${export}"} = $exports->{$export} unless defined $existing;
   }

    return keys %{ $exports };
}

# private

sub _compile_keyword {
    my ($self, $keyword, $is_global) = @_;
    
    my $compiled_code = sub {
        core_debug("[".$self->app->name."] -> $keyword(".join(', ', @_).")");
        $self->$keyword(@_);
    };

    if (! $is_global) {
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
    my ($self) = @_;
    my %map;
    foreach my $keyword (@{ $self->keywords }) {
        my ($keyword, $is_global) = @{$keyword};
        $map{$keyword} = $self->_compile_keyword($keyword, $is_global);
    }
    return \%map;
}

# TODO move that elsewhere
sub core_debug {
    my $msg = shift;
    return unless $ENV{DANCER_DEBUG_CORE};

    chomp $msg;
    print STDERR "core: $msg\n";
}

1;
