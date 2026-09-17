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
# $YAML::LoadBlessed, $YAML::LoadCode and $YAML::UseCode to 0 itself, rather
# than relying on YAML.pm's defaults. That distinction is the point of these
# tests: the variables are localised inside deserialize, so the guarantee has
# to hold even when the surrounding process has set them to something hostile.
# Each test below therefore sets the ambient values to 1 first -- which is what
# YAML.pm older than 1.30 does by default, and what Dancer2::Session::YAML
# sets for its own load -- and asserts the serializer still refuses.
#
# UseCode has to be guarded too: YAML::Loader::Base decides on code loading
# with a plain OR -- load_code($YAML::LoadCode || $YAML::UseCode) -- so an
# ambient $YAML::UseCode = 1 defeats LoadCode = 0 on its own, and the
# !!perl/code string eval is not gated on LoadBlessed at all. Hence the
# code-eval subtest below, with a side-effecting payload as its control.
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
    no warnings 'once';
    local $YAML::LoadBlessed = 1;    # hostile ambient values
    local $YAML::LoadCode    = 1;
    local $YAML::UseCode     = 1;

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
    no warnings 'once';
    local $YAML::LoadBlessed = 1;
    local $YAML::LoadCode    = 1;
    local $YAML::UseCode     = 1;
    eval { $serializer->deserialize($blessed_payload) };
    is $YAML::LoadBlessed, 1,
        'an ambient LoadBlessed is restored after deserialize returns';
    is $YAML::LoadCode, 1,
        'an ambient LoadCode is restored after deserialize returns';
    is $YAML::UseCode, 1,
        'an ambient UseCode is restored after deserialize returns';
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
    my $code_payload = qq{--- !!perl/code \x27evil { BEGIN { \$::yaml_code_ran = 1 } }\x27\n};

    subtest 'a code tag never evaluates the payload' => sub {
        # YAML::Loader::Base decides on code loading with load_code($LoadCode
        # || $UseCode), so with both ambient values hostile -- and even
        # LoadBlessed hostile, which would be irrelevant here anyway -- a
        # direct YAML::Load string-evals the payload. The serializer must not.
        no warnings 'once';
        local $YAML::LoadBlessed = 1;
        local $YAML::LoadCode    = 1;
        local $YAML::UseCode     = 1;

        undef $::yaml_code_ran;
        {
            local $SIG{__WARN__} = sub {};
            eval { YAML::Load($code_payload) };
        }
        ok $::yaml_code_ran,
            'control: the payload is evaluated when passed straight to YAML::Load'
            or diag 'attacker code was not evaluated, cannot prove the guard matters';

        undef $::yaml_code_ran;
        eval { $serializer->deserialize($code_payload) };
        ok !$::yaml_code_ran,
            'deserialize did not evaluate the supplied code'
            or diag 'attacker code ran during deserialize';
    };
}

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

    # As above, the ambient values are made hostile first; Plack::Test runs the
    # app in this process, so this localisation is what the serializer sees.
    no warnings 'once';
    local $YAML::LoadBlessed = 1;
    local $YAML::LoadCode    = 1;
    local $YAML::UseCode     = 1;

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
