package Dancer::Template::Tiny;
# ABSTRACT: Template::Tiny backend to Dancer

use strict;
use warnings;
use Carp;
use Moo;
use Dancer::Moo::Types;
use Template::Tiny;
use Dancer::FileUtils 'read_file_content';

with 'Dancer::Core::Role::Template';

has engine => (
    is => 'rw',
    default => sub { Template::Tiny->new },
    isa => sub { ObjectOf('Template::Tiny', @_) },
);

sub render {
    my ( $self, $template, $tokens ) = @_;

    ( ref $template || -f $template )
        or die "$template is not a regular file or reference";

    my $template_data = ref $template    ?
                            ${$template} :
                            read_file_content($template);

    my $content;

    $self->engine->process(
        \$template_data,
        $tokens,
        \$content,
    ) or die "Could not process template file '$template'";

    return $content;
}

1;



=pod

=head1 NAME

Dancer::Template::Tiny - Template::Tiny backend to Dancer

=head1 VERSION

version 0.03

=head1 SYNOPSIS

This template engine allows you to use L<Template::Tiny> in L<Dancer>.

L<Template::Tiny> is an implementation of a subset of L<Template::Toolkit> (the
major parts) which takes much less memory and is faster. If you're only using
the main functions of Template::Toolkit, you could use Template::Tiny. You can
also seemlessly move back to Template::Toolkit whenever you want.

You can read more on L<Template::Tiny>.

To use this engine, all you need to configure in your L<Dancer>'s
C<config.yaml>:

    template: "tiny"

Of course, you can also set this B<while> working using C<set>:

    # code code code
    set template => 'tiny';

Since L<Dancer> has internal support for a wrapper-like option with the
C<layout> configuration option, you have a WRAPPER like with
L<Template::Toolkit> even though L<Template::Tiny> doesn't really support it. :)

=head1 SUBROUTINES/METHODS

=head2 render

Renders the template. Accepts a string to a file or a reference to a string of
the template.

=head1 AUTHOR

Sawyer X, C<< <xsawyerx at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-dancer-template-tiny at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dancer-Template-Tiny>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dancer::Template::Tiny

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dancer-Template-Tiny>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Dancer-Template-Tiny>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Dancer-Template-Tiny>

=item * Search CPAN

L<http://search.cpan.org/dist/Dancer-Template-Tiny/>

=back

=head1 ACKNOWLEDGEMENTS

L<Dancer>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Sawyer X.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=head1 AUTHOR

  Sawyer X <xsawyerx@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Sawyer X.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__

