use strict;
use warnings;
use Test::More;
use Dancer2::Serializer::JSON;
use Dancer2::Serializer::YAML;

# The from_json/to_json/from_yaml/to_yaml helpers are the class-method face of
# the serializer engines: they are called as plain functions, outside any
# Dancer2 app, so there is no app logger for the engine to log to.
#
# That used to mean a failed parse raised "Class::XSAccessor: invalid instance
# method invocant" from inside the error handler -- which replaced the real
# parse error with an unrelated one (GH #1837). The helpers now build an engine
# instance with a log_cb that warns, so the diagnostic reaches the caller on
# STDERR instead of being lost. These tests pin both halves of that: the real
# error is reported, and nothing about the accessor comes back.

# Collect what the code under test says on STDERR, and give back both the
# return value and the warnings, so each subtest can assert on the pair.
sub capture_warnings {
    my $code = shift;
    my @warnings;
    local $SIG{'__WARN__'} = sub { push @warnings, @_ };
    my $result = $code->();
    return ( $result, join '', @warnings );
}

subtest 'from_json reports a parse failure instead of hiding it' => sub {
    my ( $result, $warnings )
        = capture_warnings( sub { Dancer2::Serializer::JSON::from_json('{not json') } );

    is( $result, undef, 'malformed JSON deserializes to undef' );
    like( $warnings, qr/Failed to deserialize content/,
        'and the failure is reported on STDERR' );
    unlike( $warnings, qr/Class::XSAccessor/,
        'not as an accessor error from inside the error handler' );
};

subtest 'from_yaml reports a parse failure instead of hiding it' => sub {
    my ( $result, $warnings ) = capture_warnings(
        sub { Dancer2::Serializer::YAML::from_yaml("\tbad:\n  - [unclosed") } );

    is( $result, undef, 'malformed YAML deserializes to undef' );
    like( $warnings, qr/Failed to deserialize content/,
        'and the failure is reported on STDERR' );
    unlike( $warnings, qr/Class::XSAccessor/,
        'not as an accessor error from inside the error handler' );
};

subtest 'to_json still warns about invalid UTF-8' => sub {
    # Dancer2::Serializer::JSON::_invalid_utf8 has always let this one out --
    # it warned directly whenever there was no object to log through. Now that
    # the helpers do have an object, the notice travels through log_cb, and
    # this is the test that keeps it visible rather than silently swallowed.
    my ( $json, $warnings ) = capture_warnings(
        sub { Dancer2::Serializer::JSON::to_json( { bad => pack( 'C', 0xFF ) } ) } );

    ok( $json, 'serializing bytes that are not UTF-8 still produces JSON' );
    like( $warnings, qr/Invalid UTF-8/, 'and says so on STDERR' );
};

subtest 'the helpers stay quiet when nothing is wrong' => sub {
    my ( $data, $json_warnings ) = capture_warnings( sub {
        Dancer2::Serializer::JSON::from_json(
            Dancer2::Serializer::JSON::to_json( { a => 1, b => [ 1, 2 ] } ) );
    } );

    is_deeply( $data, { a => 1, b => [ 1, 2 ] }, 'JSON round trips' );
    is( $json_warnings, '', 'and warns about nothing' );

    my ( $yaml_data, $yaml_warnings ) = capture_warnings( sub {
        Dancer2::Serializer::YAML::from_yaml(
            Dancer2::Serializer::YAML::to_yaml( { a => 1, b => [ 1, 2 ] } ) );
    } );

    is_deeply( $yaml_data, { a => 1, b => [ 1, 2 ] }, 'YAML round trips' );
    is( $yaml_warnings, '', 'and warns about nothing either' );
};

subtest 'a bare class-method call fails quietly rather than dying' => sub {
    # Not just the helpers: any caller can invoke the engines as class methods,
    # and Role::Serializer's error handler now guards its log_cb call with
    # blessed(). There is nowhere to report to on this path, so the failure is
    # silent -- but it must not raise.
    my ( $outcome, $warnings ) = capture_warnings( sub {
        my $result = eval { Dancer2::Serializer::JSON->deserialize('{not json') };
        return { result => $result, error => $@ };
    } );

    is( $outcome->{'error'}, '',
        'a class-method deserialize of malformed JSON does not die' );
    is( $outcome->{'result'}, undef, 'it returns undef' );
    unlike( $warnings, qr/Class::XSAccessor/, 'and raises no accessor error' );
};

done_testing();
