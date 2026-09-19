requires 'perl', 5.014000;
requires 'Attribute::Handlers';
requires 'Carp';
requires 'Clone';
requires 'Config::Any';
requires 'Crypt::URandom', '0.36';
requires 'Data::Censor' => '0.04';
requires 'Digest::SHA';
requires 'Encode';
requires 'Exporter', '5.57';
requires 'Exporter::Tiny';
requires 'File::Copy';
requires 'File::Path';
requires 'File::Share';
requires 'File::Temp';
requires 'Hash::Merge::Simple';
requires 'Hash::MultiValue';
requires 'HTTP::Date';
requires 'HTTP::Headers::Fast', '0.21';
requires 'HTTP::Tiny';
requires 'Import::Into';
requires 'JSON::MaybeXS';
requires 'List::Util', '1.29';   # 1.29 has the pair* functions
requires 'MIME::Base64', '3.13'; # 3.13 has the URL safe variants
requires 'Module::Runtime';
requires 'Moo', '2.000000';
requires 'Moo::Role';
requires 'parent';
requires 'Path::Tiny';
requires 'Plack', '1.0040';
requires 'Plack::Middleware::FixMissingBodyInRedirect';
requires 'Plack::Middleware::RemoveRedundantBody';
requires 'POSIX';
requires 'Ref::Util';
requires 'Safe::Isa';
requires 'Sub::Quote';
requires 'Template';
requires 'Template::Tiny', '1.16';
requires 'Test::Builder';
requires 'Test::More';
requires 'Types::Standard';
requires 'Type::Tiny', '1.000006';
requires 'URI::Escape';
requires 'CLI::Osprey','0.09';
requires 'File::Which';
requires 'Sub::Util';

requires 'Role::Tiny', '2.000000';
conflicts 'Role::Tiny', '== 2.000007';

# Module::Pluggable 6.1 and 6.2 fail their test suite when run as root,
# such as under docker in a github action
requires 'Module::Pluggable';
conflicts 'Module::Pluggable', '== 6.1';
conflicts 'Module::Pluggable', '== 6.2';

# Dancer2::Serializer::YAML hands untrusted request bodies to YAML::Load, so
# the floor here is a security constraint, decided as follows:
#
#   1.25  introduced $YAML::LoadBlessed. The serializer sets it to 0 itself so
#         the protection does not depend on YAML.pm's ambient default -- but
#         below 1.25 the variable does not exist and setting it is a silent
#         no-op, leaving !!perl/hash:Some::Class able to instantiate an
#         arbitrary blessed object from a request body.
#   1.26  fixed a parsing regression introduced in 1.25.
#   1.28  "only enable loading globs when $LoadCode is set" -- an upstream
#         security fix in the same load path we expose to untrusted input, and
#         unlike LoadBlessed it is behavioural, so we cannot reproduce it from
#         our side on older versions. This is the real security floor.
#   1.30  changed the $YAML::LoadBlessed default to 0. We override it
#         explicitly either way, so this adds nothing functionally -- but it is
#         from January 2020 and costs nothing, and it keeps the safe behaviour
#         if our explicit setting is ever lost in a refactor.
#
# The serializer also zeroes $YAML::UseCode, because the loader ORs it into
# its code-loading decision (load_code($YAML::LoadCode || $YAML::UseCode)) and
# an ambient $YAML::UseCode = 1 would otherwise defeat the LoadCode setting.
# UseCode has existed since long before any of the above, so it changes
# nothing about the 1.30 floor.
#
# 1.30 also supersedes two older constraints, no longer declared separately:
# a floor of 0.86 (https://github.com/PerlDancer/Dancer2/issues/899), and an
# exclusion of the broken 1.16 (cpantesters reports
# 25911c10-4199-11e6-8d7d-86c55bc2a771 and 284ac158-419a-11e6-9a35-e3e15bc2a771).
requires 'YAML', '1.30';

recommends 'CGI::Deurl::XS';
recommends 'Class::XSAccessor';
recommends 'Cpanel::JSON::XS';
recommends 'HTTP::XSCookies', '0.000015';
recommends 'HTTP::XSHeaders';
recommends 'MooX::TypeTiny';
recommends 'Pod::Simple::Search';
recommends 'Pod::Simple::SimpleTree';
recommends 'Type::Tiny::XS';
recommends 'URL::Encode::XS';
recommends 'YAML::XS';
recommends 'Unicode::UTF8';

suggests 'Fcntl';
suggests 'MIME::Types';

test_requires 'Capture::Tiny', '0.12';
test_requires 'HTTP::Cookies';
test_requires 'HTTP::Headers';
test_requires 'Pod::Simple::SimpleTree';
test_requires 'Template';
test_requires 'Test::Builder';
test_requires 'Test::EOL';
test_requires 'Test::Fatal';
test_requires 'Test::More';
test_requires 'Test::More', '0.92';
test_requires 'Test::Exception';

author_requires 'Test::NoTabs';
author_requires 'Test::Pod';
author_requires 'AnyEvent';
author_requires 'CBOR::XS';
author_requires 'Class::Method::Modifiers';
author_requires 'Dist::Zilla::Plugin::Test::UnusedVars';
author_requires 'Perl::Tidy';
author_requires 'Test::Memory::Cycle';
author_requires 'Test::MockTime';
author_requires 'Test::Perl::Critic';
author_requires 'Test::Whitespaces';
author_requires 'YAML::XS';
