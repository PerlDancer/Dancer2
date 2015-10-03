package Dancer2::Template::Implementation::ForkedTiny;

# ABSTRACT: Dancer2 own implementation of Template::Tiny

use 5.00503;
use strict;
no warnings;

# Evaluatable expression
my $EXPR = qr/ [a-z_][\w.]* /xs;

sub new {
    my $self = bless {
        start_tag => '[%',
        end_tag   => '%]',
        @_[ 1 .. $#_ ]
      },
      $_[0];

# Opening tag including whitespace chomping rules
    my $LEFT = $self->{LEFT} = qr/
    (?:
        (?: (?:^|\n) [ \t]* )? \Q$self->{start_tag}\E\-
        |
        \Q$self->{start_tag}\E \+?
    ) \s*
/xs;

# Closing %] tag including whitespace chomping rules
    my $RIGHT = $self->{RIGHT} = qr/
    \s* (?:
        \+? \Q$self->{end_tag}\E
        |
        \-\Q$self->{end_tag}\E (?: [ \t]* \n )?
    )
/xs;

# Preparsing run for nesting tags
    $self->{PREPARSE} = qr/
    $LEFT ( IF | UNLESS | FOREACH ) \s+
        (
            (?: \S+ \s+ IN \s+ )?
        \S+ )
    $RIGHT
    (?!
        .*?
        $LEFT (?: IF | UNLESS | FOREACH ) \b
    )
    ( .*? )
    (?:
        $LEFT ELSE $RIGHT
        (?!
            .*?
            $LEFT (?: IF | UNLESS | FOREACH ) \b
        )
        ( .+? )
    )?
    $LEFT END $RIGHT
/xs;

    $self->{CONDITION} = qr/
    \Q$self->{start_tag}\E\s
        ( ([IUF])\d+ ) \s+
        (?:
            ([a-z]\w*) \s+ IN \s+
        )?
        ( $EXPR )
    \s\Q$self->{end_tag}\E
    ( .*? )
    (?:
        \Q$self->{start_tag}\E\s \1 \s\Q$self->{end_tag}\E
        ( .+? )
    )?
    \Q$self->{start_tag}\E\s \1 \s\Q$self->{end_tag}\E
/xs;

    $self;
}

# Copy and modify
sub preprocess {
    my $self = shift;
    my $text = shift;
    $self->_preprocess( \$text );
    return $text;
}

sub process {
    my $self  = shift;
    my $copy  = ${ shift() };
    my $stash = shift || {};

    local $@  = '';
    local $^W = 0;

    # Preprocess to establish unique matching tag sets
    $self->_preprocess( \$copy );

    # Process down the nested tree of conditions
    my $result = $self->_process( $stash, $copy );
    if (@_) {
        ${ $_[0] } = $result;
    }
    elsif ( defined wantarray ) {
        require Carp;
        Carp::carp(
            'Returning of template results is deprecated in Template::Tiny 0.11'
        );
        return $result;
    }
    else {
        print $result;
    }
}


######################################################################
# Support Methods

# The only reason this is a standalone is so we can
# do more in-depth testing.
sub _preprocess {
    my $self = shift;
    my $copy = shift;

    # Preprocess to establish unique matching tag sets
    my $id = 0;
    1 while $$copy =~ s/
        $self->{PREPARSE}
    /
        my $tag = substr($1, 0, 1) . ++$id;
        "\[\% $tag $2 \%\]$3\[\% $tag \%\]"
        . (defined($4) ? "$4\[\% $tag \%\]" : '');
    /sex;
}

sub _process {
    my ( $self, $stash, $text ) = @_;

    $text =~ s/
        $self->{CONDITION}
    /
        ($2 eq 'F')
            ? $self->_foreach($stash, $3, $4, $5)
            : eval {
                $2 eq 'U'
                xor
                !! # Force boolification
                $self->_expression($stash, $4)
            }
                ? $self->_process($stash, $5)
                : $self->_process($stash, $6)
    /gsex;

    # Resolve expressions
    $text =~ s/
        $self->{LEFT} ( $EXPR ) $self->{RIGHT}
    /
        eval {
            $self->_expression($stash, $1)
            . '' # Force stringification
        }
    /gsex;

    # Trim the document
    $text =~ s/^\s*(.+?)\s*\z/$1/s if $self->{TRIM};

    return $text;
}

# Special handling for foreach
sub _foreach {
    my ( $self, $stash, $term, $expr, $text ) = @_;

    # Resolve the expression
    my $list = $self->_expression( $stash, $expr );
    if ( ref $list ne 'ARRAY' ) {
        return '';
    }

    # Iterate
    return join '',
      map { $self->_process( { %$stash, $term => $_ }, $text ) } @$list;
}

# Evaluates a stash expression
sub _expression {
    my $cursor = $_[1];
    my @path = split /\./, $_[2];
    foreach (@path) {

        # Support for private keys
        return if substr( $_, 0, 1 ) eq '_';

        # Split by data type
        my $type = ref $cursor;
        if ( $type eq 'ARRAY' ) {
            return '' unless /^(?:0|[0-9]\d*)\z/;
            $cursor = $cursor->[$_];
        }
        elsif ( $type eq 'HASH' ) {
            $cursor = $cursor->{$_};
        }
        elsif ($type) {
            $cursor = $cursor->$_();
        }
        else {
            return '';
        }
    }

    # If the last expression is a CodeRef, execute it
    ref($cursor) eq 'CODE'
      and $cursor = $cursor->();
    return $cursor;
}

1;

__END__

=pod

=head1 NAME

Dancer2::Template::Implementation::ForkedTiny - Template Toolkit reimplemented in as little code as possible, forked from Template::Tiny

=head1 SYNOPSIS

  my $template = Dancer2::Template::Implementation::ForkedTiny->new(
      TRIM => 1,
  );

  # Print the template results to STDOUT
  $template->process( <<'END_TEMPLATE', { foo => 'World' } );
  Hello [% foo %]!
  END_TEMPLATE

=head1 DESCRIPTION

B<Dancer2::Template::Implementation::ForkedTiny> is a reimplementation of a subset of the functionality from
L<Template> Toolkit in as few lines of code as possible.

It is intended for use in light-usage, low-memory, or low-cpu templating
situations, where you may need to upgrade to the full feature set in the
future, or if you want the retain the familiarity of TT-style templates.

For the subset of functionality it implements, it has fully-compatible template
and stash API. All templates used with B<Dancer2::Template::Implementation::ForkedTiny> should be able to be
transparently upgraded to full Template Toolkit.

Unlike Template Toolkit, B<Dancer2::Template::Implementation::ForkedTiny> will process templates without a
compile phase (but despite this is still quicker, owing to heavy use of
the Perl regular expression engine.

=head2 SUPPORTED USAGE

By default, the C<[% %]> tag style is used. You can change the start tag and
end tag by specifying them at object creation :

  my $template = Dancer2::Template::Implementation::ForkedTiny->new(
      start_tag => '<%',
      end_tag => '%>,
  );

In the rest of the documentation, C<[% %]> will be used, but it can be of
course your specified start / end tags.

Both the C<[%+ +%]> style explicit whitespace and the C<[%- -%]> style
explicit chomp B<are> support, although the C<[%+ +%]> version is unneeded
in practice as B<Dancer2::Template::Implementation::ForkedTiny> does not support default-enabled C<PRE_CHOMP>
or C<POST_CHOMP>.

Variable expressions in the form C<[% foo.bar.baz %]> B<are> supported.

Appropriate simple behaviours for C<ARRAY> references, C<HASH> references and
objects are supported. "VMethods" such as [% array.length %] are B<not>
supported at this time.

If the resulting expression is a CodeRef, it'll be evaluated.

C<IF>, C<ELSE> and C<UNLESS> conditional blocks B<are> supported, but only with
simple C<[% foo.bar.baz %]> conditions.

Support for looping (or rather iteration) is available in simple
C<[% FOREACH item IN list %]> form B<is> supported. Other loop structures are
B<not> supported. Because support for arbitrary or infinite looping is not
available, B<Dancer2::Template::Implementation::ForkedTiny> templates are not turing complete. This is
intentional.

All of the four supported control structures C<IF>/C<ELSE>/C<UNLESS>/C<FOREACH>
can be nested to arbitrary depth.

The treatment of C<_private> hash and method keys is compatible with
L<Template> Toolkit, returning null or false rather than the actual content
of the hash key or method.

Anything beyond the above is currently out of scope.

=head1 METHODS

=head2 new

  my $template = Dancer2::Template::Implementation::ForkedTiny->new(
      TRIM => 1,
  );

The C<new> constructor is provided for compatibility with Template Toolkit.

The only parameter it currently supports is C<TRIM> (which removes leading
and trailing whitespace from processed templates).

Additional parameters can be provided without error, but will be ignored.

=head2 process

  # DEPRECATED: Return template results (emits a warning)
  my $text = $template->process( \$input, $vars );

  # Print template results to STDOUT
  $template->process( \$input, $vars );

  # Generate template results into a variable
  my $output = '';
  $template->process( \$input, $vars, \$output );

The C<process> method is called to process a template.

The first parameter is a reference to a text string containing the template
text. A reference to a hash may be passed as the second parameter containing
definitions of template variables.

If a third parameter is provided, it must be a scalar reference to be
populated with the output of the template.

For a limited amount of time, the old deprecated interface will continue to
be supported. If C<process> is called without a third parameter, and in
scalar or list contest, the template results will be returned to the caller.

If C<process> is called without a third parameter, and in void context, the
template results will be C<print()>ed to the currently selected file handle
(probably C<STDOUT>) for compatibility with L<Template>.

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Template-Tiny>

For other issues, or commercial enhancement or support, contact the author.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

Forked and improved by Damien Krotkine E<lt>dams@cpan.orgE<gt>

=head1 SEE ALSO

L<Config::Tiny>, L<CSS::Tiny>, L<YAML::Tiny>

=head1 COPYRIGHT

Copyright 2009 - 2011 Adam Kennedy.
Copyright 2012 Damien Krotkine.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
