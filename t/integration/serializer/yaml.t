use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request;
use Scalar::Util 'blessed';

use Dancer2::Serializer::YAML;

# YAML tags can ask the loader to build things that are not data. The two that
# matter for a serializer fed untrusted request bodies are:
#
#   !!perl/hash:Some::Class   instantiate an arbitrary blessed object, which is
#                             the entry point for DESTROY/AUTOLOAD gadget chains
#   !!perl/code               string-eval a sub body
#
# Dancer2::Serializer::YAML::deserialize refuses both by setting
# $YAML::LoadBlessed and $YAML::LoadCode to 0 itself, rather than relying on
# YAML.pm's defaults. That distinction is the point of these tests: the
# variables are localised inside deserialize, so the guarantee has to hold even
# when the surrounding process has set them to something hostile. Each test
# below therefore sets the ambient value to 1 first -- which is what YAML.pm
# older than 1.30 does by default, and what Dancer2::Session::YAML sets for its
# own load -- and asserts the serializer still refuses.
#
# The assertions deliberately test only the security property -- "no
# Attacker::Gadget object comes back" -- and not the exact shape of what does.
# That shape is YAML-version-dependent: with LoadBlessed off, YAML 1.30 and
# earlier silently strip the tag and return a plain hash, while newer YAML
# rejects the document outright (which deserialize turns into undef for an
# engine instance). Both satisfy the guarantee; pinning either one made the
# test pass on the author's YAML and fail on CI's.
#
# For the same reason every deserialize below is called on an *instance*, which
# is how the framework itself always calls it. A class-method call routes a
# rejection through Dancer2::Core::Role::Serializer's error handler, which is
# not class-safe (see GH #1837) and dies with an unrelated internal error --
# noise that has nothing to do with what these tests are about.

my $blessed_payload = qq{--- !!perl/hash:Attacker::Gadget\nfoo: bar\n};

my $serializer = Dancer2::Serializer::YAML->new( log_cb => sub {} );

subtest 'a blessing tag never yields the attacker-named object' => sub {
    local $YAML::LoadBlessed = 1;    # hostile ambient value

    my $data = eval { $serializer->deserialize($blessed_payload) };

    ok !( blessed($data) && $data->isa('Attacker::Gadget') ),
        'deserialize did not return an Attacker::Gadget object'
        or diag "got: " . ( blessed($data) || ref($data) || 'undef' );

    # Sanity check on the payload itself: with the guard bypassed it really
    # does bless. Without this, the assertion above would also pass on a YAML
    # that could not bless at all, and would prove nothing.
    my $direct = eval { YAML::Load($blessed_payload) };
    ok( blessed($direct) && $direct->isa('Attacker::Gadget'),
        'control: the payload blesses when passed straight to YAML::Load' )
        or diag "control got: " . ( blessed($direct) || ref($direct) || 'undef' );
};

subtest 'the localisation does not leak' => sub {
    local $YAML::LoadBlessed = 1;
    eval { $serializer->deserialize($blessed_payload) };
    is $YAML::LoadBlessed, 1,
        'an ambient LoadBlessed is restored after deserialize returns';
};

subtest 'ordinary YAML still round-trips' => sub {
    my $data = { name => 'dancer', list => [ 1, 2, 3 ], nested => { a => 'b' } };
    my $out  = $serializer->deserialize( $serializer->serialize($data) );

    is_deeply $out, $data, 'a normal structure survives a round trip unchanged';

    is_deeply(
        $serializer->deserialize("---\n- one\n- two\n"),
        [ 'one', 'two' ],
        'a top-level sequence still loads',
    );
};

{
    package YAMLApp;
    use Dancer2;
    set logger     => 'null';
    set serializer => 'YAML';

    post '/echo' => sub {
        my $body = request->data;
        return {
            # fully qualified: Scalar::Util is not imported into this package
            blessed_into => Scalar::Util::blessed($body) || '',
            ref          => ref($body) || 'none',
        };
    };
}

subtest 'a blessing payload sent as a request body never blesses' => sub {
    my $app = YAMLApp->to_app;

    # As above, the ambient value is made hostile first; Plack::Test runs the
    # app in this process, so this localisation is what the serializer sees.
    local $YAML::LoadBlessed = 1;

    test_psgi $app, sub {
        my $cb = shift;

        my $req = HTTP::Request->new(
            POST => '/echo',
            [ 'Content-Type' => 'text/x-yaml' ],
            $blessed_payload,
        );

        my $res = $cb->($req);

        # 200 (older YAML strips the tag, route sees a plain hash) or a clean
        # 4xx/5xx (newer YAML rejects the document) are both acceptable. What
        # must never happen is an Attacker::Gadget reaching the route or the
        # class name surfacing in the response.
        unlike $res->content, qr/Attacker::Gadget/,
            'no blessed gadget leaked into the response';

        if ( $res->code == 200 ) {
            my $out = $serializer->deserialize( $res->content );
            is $out->{blessed_into}, '',
                'the route saw an unblessed value';
        }
        else {
            ok $res->code >= 400,
                'a rejected body produced an error status, not a gadget';
        }
    };
};

done_testing;
