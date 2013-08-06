# Dancer2

[![Build Status](https://travis-ci.org/PerlDancer/Dancer2.png?branch=devel)](https://travis-ci.org/PerlDancer/Dancer2)

Dancer2 is the new generation lightweight web-framework for Perl.

You can install it from the CPAN:

    $ cpan install Dancer2

An application can be as simple as this simple hello world script:

```perl
use Dancer2;
get '/' => sub { 
    "Hello World" 
};
dance;
```

You can run it with

    $ perl app.pl

Now point your browser to [http://localhost:3000](http://localhost:3000) and voilà!

## Useful Resources

* [Dancer's Website](http://perldancer.org)
* [Most recent release on CPAN](https://metacpan.org/release/Dancer2)
* [Builds status on Travis](https://travis-ci.org/PerlDancer/Dancer2)
* [Our Mailing List](http://list.perldancer.org/cgi-bin/listinfo/dancer-users)
* [Follow us on Twitter](https://twitter.com/perldancer)
* [Find us on irc.per.org #dancer](irc://irc.perl.org/#dancer)
* [The Advent Calendar](http://advent.perldancer.org/)
* [Contribution/Git Guide](https://github.com/PerlDancer/Dancer2/blob/devel/GitGuide.md)

## Available Plugins

| Name         | Links |
|------------- |------|
| Dancer2::Session::Cookie | [CPAN](https://metacpan.org/module/Dancer2::Session::Cookie) [GitHub](https://github.com/dagolden/dancer2-session-cookie) |
| Dancer2::Plugin::Syntax::GetPost | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Syntax::GetPost) [GitHub](https://github.com/dagolden/dancer2-plugin-syntax-getpost) |
| Dancer2::Plugin::BrowserDetect | [CPAN](https://metacpan.org/module/Dancer2::Plugin::BrowserDetect) |
| Dancer2::Plugin::RoutePodCoverage | [CPAN](https://metacpan.org/module/Dancer2::Plugin::RoutePodCoverage)[GitHub](https://github.com/drebolo/Dancer2-Plugin-RoutePodCoverage) |
| Dancer2::Plugin::Auth::Tiny | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Auth::Tiny) [GitHub](https://metacpan.org/module/Dancer2::Plugin::Auth::Tiny) |
| Dancer2::Plugin::Queue::MongoDB | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Queue::MongoDB) [GitHub](https://github.com/dagolden/dancer2-plugin-queue-mongodb) |
| Dancer2::Plugin::Paginator | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Paginator) [GitHub](https://github.com/blabos/Dancer2-Plugin-Paginator) |
| Dancer2::Plugin::Deferred | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Deferred) [GitHub](https://github.com/dagolden/dancer2-plugin-deferred) |
| Dancer2::Plugin::Adapter | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Adapter) [GitHub](https://github.com/dagolden/dancer2-plugin-adapter) |
| Dancer2::Plugin::DBIC | [CPAN](https://metacpan.org/module/Dancer2::Plugin::DBIC) [GitHub](https://github.com/ironcamel/Dancer2-Plugin-DBIC) |
| Dancer2::Plugin::REST | [CPAN](https://metacpan.org/module/Dancer2::Plugin::REST) |
| Dancer2::Plugin::Emailesque | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Emailesque) |
| Dancer2::Plugin::Cache::CHI | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Cache::CHI) [GitHub](https://github.com/yanick/Dancer2-Plugin-Cache-CHI) |
| Dancer2::Plugin::Queue | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Queue) [GitHub](https://github.com/dagolden/dancer2-plugin-queue) |
| Dancer2::Plugin::Database | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Database) |
| Dancer2::Plugin::Feed | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Feed) |


## Templates engines

| Name | Links |
|------|-------|
| Dancer2::Template::Xslate | [CPAN](https://metacpan.org/module/Dancer2::Template::Xslate) [GitHub](https://github.com/rsimoes/Dancer2-Template-Xslate) |
| Dancer2::Template::MojoTemplate | [CPAN](https://metacpan.org/module/Dancer2::Template::MojoTemplate) [GitHub](https://github.com/VeroLom/Dancer2-Template-MojoTemplate) |
| Dancer2::Template::Caribou | [CPAN](https://metacpan.org/module/Dancer2::Template::Caribou) [GitHub](https://github.com/yanick/Dancer2-Template-Caribou) |


## License

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
