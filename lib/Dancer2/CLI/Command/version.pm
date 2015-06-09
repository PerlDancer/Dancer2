package Dancer2::CLI::Command::version;
# ABSTRACT: display version
$Dancer2::CLI::Command::version::VERSION = '0.159002';
use App::Cmd::Setup -command;

sub description { 'Display version of Dancer2' }

sub command_names {
    qw/version --version -v/;
}

sub execute {
    require Dancer2;
    print 'Dancer2 ' . $Dancer2::VERSION . "\n";
    return 0;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::CLI::Command::version - display version

=head1 VERSION

version 0.159002

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
