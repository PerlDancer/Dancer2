use strict;
use warnings;
use Test::More tests => 5;
use Test::Fatal;

use_ok('Dancer2::Core::Hook');

{
    package Serializer::OK;
    use Moo;
    with 'Dancer2::Core::Role::Serializer';
    has '+content_type' => ( default => sub {'plain/test'} );

    sub serialize   {'{'.$_[1].'}'}
    sub deserialize {'['.$_[1].']'}
}

subtest 'Successful' => sub {
    plan tests => 5;

    my $srl = Serializer::OK->new;
    isa_ok( $srl, 'Serializer::OK' );

    $srl->add_hook(
        Dancer2::Core::Hook->new(
            name => 'engine.serializer.before',
            code => sub {
                my $content = shift;
                ::is( $content, 'foo', 'Correct content in before hook' );
            },
        )
    );

    $srl->add_hook(
        Dancer2::Core::Hook->new(
            name => 'engine.serializer.after',
            code => sub {
                my $content = shift;
                ::is( $content, '{foo}', 'Correct content in after hook' );
            },
        )
    );

    is( $srl->serialize('foo'),   '{foo}', 'Serializing'   );
    is( $srl->deserialize('bar'), '[bar]', 'Deserializing' );
};

{
    package Serializer::NotOK;
    use Moo;
    with 'Dancer2::Core::Role::Serializer';
    has '+content_type' => ( default => sub {'plain/test'} );

    sub serialize   { die '+' . $_[1] . '+' }
    sub deserialize { die '-' . $_[1] . '-' }
}

subtest 'Unsuccessful' => sub {
    plan tests => 21;

    use_ok('Dancer2::Logger::Capture');

    {
        my $logger = Dancer2::Logger::Capture->new;
        isa_ok( $logger, 'Dancer2::Logger::Capture' );

        my $srl = Serializer::NotOK->new(
            log_cb => sub { $logger->log(@_) }
        );

        isa_ok( $srl, 'Serializer::NotOK' );
        is( $srl->serialize('foo'), undef, 'Serialization result' );

        my $trap = $logger->trapper;
        isa_ok( $trap, 'Dancer2::Logger::Capture::Trap' );

        my $errors = $trap->read;
        isa_ok( $errors, 'ARRAY' );
        is( scalar @{$errors}, 1, 'One error caught' );

        my $msg = $errors->[0];
        isa_ok( $msg, 'HASH' );
        is( scalar keys %{$msg}, 3, 'Two items in the error' );

        is( $msg->{'level'}, 'core', 'Correct level' );
        like(
            $msg->{'message'},
            qr{^Failed to serialize the request: \+foo\+},
            'Correct error message',
        );
    }

    {
        my $logger = Dancer2::Logger::Capture->new;
        isa_ok( $logger, 'Dancer2::Logger::Capture' );

        my $srl = Serializer::NotOK->new(
            log_cb => sub { $logger->log(@_) }
        );

        isa_ok( $srl, 'Serializer::NotOK' );
        is( $srl->deserialize('bar'), undef, 'Deserialization result' );

        my $trap = $logger->trapper;
        isa_ok( $trap, 'Dancer2::Logger::Capture::Trap' );

        my $errors = $trap->read;
        isa_ok( $errors, 'ARRAY' );
        is( scalar @{$errors}, 1, 'One error caught' );

        my $msg = $errors->[0];
        isa_ok( $msg, 'HASH' );
        is( scalar keys %{$msg}, 3, 'Two items in the error' );

        is( $msg->{'level'}, 'core', 'Correct level' );
        like(
            $msg->{'message'},
            qr{^Failed to deserialize the request: \-bar\-},
            'Correct error message',
        );
    }
};

{
    package Serializer::Generic;
    use Moo;
    with 'Dancer2::Core::Role::Serializer';
    has '+content_type' => ( default => 'plain/test' );
    sub serialize   {1}
    sub deserialize {1}
}

subtest 'support_content_type' => sub {
    plan tests => 7;

    my $srl = Serializer::Generic->new;
    isa_ok( $srl, 'Serializer::Generic'  );
    can_ok( $srl, 'support_content_type' );

    is( $srl->support_content_type(), undef, 'Empty returns undef' );

    is(
        $srl->support_content_type('plain/foo;plain/bar'),
        '',
        'Content type not supported',
    );

    is(
        $srl->support_content_type('plain/foo;plain/test'),
        '',
        'Content type not supported (because not first)',
    );

    is(
        $srl->support_content_type('plain/test'),
        1,
        'Content type supported when single',
    );

    is(
        $srl->support_content_type('plain/test;plain/foo'),
        1,
        'Content type supported when first',
    );
};

{
    package Serializer::Empty;
    use Moo;
    with 'Dancer2::Core::Role::Serializer';
    has '+content_type' => ( default => 'plain/test' );
    sub serialize   {'BAD SERIALIZE'}
    sub deserialize {'BAD DESERIALIZE'}
}

subtest 'Called with empty content' => sub {
    plan tests => 6;

    my $srl = Serializer::Empty->new;
    isa_ok( $srl, 'Serializer::Empty'  );
    can_ok( $srl, qw<serialize deserialize> );

    is(
        $srl->serialize(),
        undef,
        'Do not try to serialize without input',
    );

    is(
        $srl->serialize(''),
        '',
        'Do not try to serialize with empty input',
    );

    is(
        $srl->deserialize(),
        undef,
        'Do not try to deserialize without input',
    );

    is(
        $srl->deserialize(''),
        '',
        'Do not try to deserialize with empty input',
    );
}

