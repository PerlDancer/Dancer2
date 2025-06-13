package CustomCensor;

sub censor {
    my $data = shift;

    $data->{personal} = 'for my eyes only';

    return 1;
}

1;
