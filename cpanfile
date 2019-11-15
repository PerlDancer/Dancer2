requires 'App::Cmd::Setup';
requires 'Attribute::Handlers';
requires 'Carp';
requires 'Clone';
requires 'Config::Any';
requires 'Digest::SHA';
requires 'Encode';
requires 'Exporter', '5.57';
requires 'Exporter::Tiny';
requires 'File::Basename';
requires 'File::Copy';
requires 'File::Find';
requires 'File::Path';
requires 'File::Share';
requires 'File::Spec';
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
requires 'Plack', '1.0040';
requires 'Plack::Middleware::FixMissingBodyInRedirect';
requires 'Plack::Middleware::RemoveRedundantBody';
requires 'POSIX';
requires 'Ref::Util';
requires 'Role::Tiny', '2.000000';
requires 'Safe::Isa';
requires 'Sub::Quote';
requires 'Template';
requires 'Template::Tiny';
requires 'Test::Builder';
requires 'Test::More';
requires 'Types::Standard';
requires 'Type::Tiny', '1.000006';
requires 'URI::Escape';

# Minimum version of YAML is needed due to:
# - https://github.com/PerlDancer/Dancer2/issues/899
# Excluded 1.16 is needs due to:
# - http://www.cpantesters.org/cpan/report/25911c10-4199-11e6-8d7d-86c55bc2a771
# - http://www.cpantesters.org/cpan/report/284ac158-419a-11e6-9a35-e3e15bc2a771
requires 'YAML', '0.86';
conflicts 'YAML', '1.16';

recommends 'CGI::Deurl::XS';
recommends 'Class::XSAccessor';
recommends 'Cpanel::JSON::XS';
recommends 'Crypt::URandom';
recommends 'HTTP::XSCookies', '0.000007';
recommends 'HTTP::XSHeaders';
recommends 'Math::Random::ISAAC::XS';
recommends 'MooX::TypeTiny';
recommends 'Pod::Simple::Search';
recommends 'Pod::Simple::SimpleTree';
recommends 'Scope::Upper';
recommends 'Type::Tiny::XS';
recommends 'URL::Encode::XS';
recommends 'YAML::XS';

suggests 'Fcntl';
suggests 'MIME::Types';

test_requires 'Capture::Tiny', '0.12';
test_requires 'HTTP::Cookies';
test_requires 'HTTP::Headers';
test_requires 'Template';
test_requires 'Test::Builder';
test_requires 'Test::EOL';
test_requires 'Test::Fatal';
test_requires 'Test::More';
test_requires 'Test::More', '0.92';

build_requires 'Test::CPAN::Meta';

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
