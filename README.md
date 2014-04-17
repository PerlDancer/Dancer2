# Dancer2

[![Build Status](https://travis-ci.org/PerlDancer/Dancer2.png?branch=master)](https://travis-ci.org/PerlDancer/Dancer2)

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
* [Our Mailing List](http://lists.preshweb.co.uk/mailman/listinfo/dancer-users)
* [Follow us on Twitter](https://twitter.com/perldancer)
* [Find us on irc.perl.org #dancer](http://perldancer.org/irc)
* [The Advent Calendar](http://advent.perldancer.org/)
* [Contribution/Git Guide](https://github.com/PerlDancer/Dancer2/blob/master/GitGuide.md)

## Available Plugins

| Name | CPAN  | GitHub |
|------|-------|--------|
| Dancer2::Session::Cookie | [Link](https://metacpan.org/module/Dancer2::Session::Cookie) | [Link](https://github.com/dagolden/dancer2-session-cookie) |
| Dancer2::Plugin::Syntax::GetPost | [Link](https://metacpan.org/module/Dancer2::Plugin::Syntax::GetPost) | [Link](https://github.com/dagolden/dancer2-plugin-syntax-getpost) |
| Dancer2::Plugin::BrowserDetect | [Link](https://metacpan.org/module/Dancer2::Plugin::BrowserDetect) | |
| Dancer2::Plugin::RoutePodCoverage | [Link](https://metacpan.org/module/Dancer2::Plugin::RoutePodCoverage) | [Link](https://github.com/drebolo/Dancer2-Plugin-RoutePodCoverage) |
| Dancer2::Plugin::Auth::Tiny | [Link](https://metacpan.org/module/Dancer2::Plugin::Auth::Tiny) | [Link](https://metacpan.org/module/Dancer2::Plugin::Auth::Tiny) |
| Dancer2::Plugin::Queue::MongoDB | [Link](https://metacpan.org/module/Dancer2::Plugin::Queue::MongoDB)  | [Link](https://github.com/dagolden/dancer2-plugin-queue-mongodb) |
| Dancer2::Plugin::Paginator | [Link](https://metacpan.org/module/Dancer2::Plugin::Paginator) | [Link](https://github.com/blabos/Dancer2-Plugin-Paginator) |
| Dancer2::Plugin::Deferred | [Link](https://metacpan.org/module/Dancer2::Plugin::Deferred) | [Link](https://github.com/dagolden/dancer2-plugin-deferred) |
| Dancer2::Plugin::Adapter | [Link](https://metacpan.org/module/Dancer2::Plugin::Adapter) | [Link](https://github.com/dagolden/dancer2-plugin-adapter) |
| Dancer2::Plugin::DBIC | [Link](https://metacpan.org/module/Dancer2::Plugin::DBIC) | [Link](https://github.com/ironcamel/Dancer2-Plugin-DBIC) |
| Dancer2::Plugin::REST | [Link](https://metacpan.org/module/Dancer2::Plugin::REST) | [Link](https://github.com/yanick/Dancer2-Plugin-REST) |
| Dancer2::Plugin::Emailesque | [Link](https://metacpan.org/module/Dancer2::Plugin::Emailesque) | [Link](https://github.com/ambs/Dancer2-Plugin-Emailesque) |
| Dancer2::Plugin::Cache::CHI | [Link](https://metacpan.org/module/Dancer2::Plugin::Cache::CHI) | [Link](https://github.com/yanick/Dancer2-Plugin-Cache-CHI) |
| Dancer2::Plugin::Queue | [Link](https://metacpan.org/module/Dancer2::Plugin::Queue) | [Link](https://github.com/dagolden/dancer2-plugin-queue) |
| Dancer2::Plugin::Database | [Link](https://metacpan.org/module/Dancer2::Plugin::Database) | [Link](https://github.com/bigpresh/Dancer-Plugin-Database/tree/master/Dancer2) |
| Dancer2::Plugin::Feed | [Link](https://metacpan.org/module/Dancer2::Plugin::Feed) | [Link](https://github.com/hobbestigrou/Dancer2-Plugin-Feed) |
| Dancer2::Plugin::Sixpack | [Link](https://metacpan.org/module/Dancer2::Plugin::Sixpack) | [Link](https://github.com/b10m/p5-Dancer2-Plugin-Sixpack) |


## Templates engines

| Name | CPAN | GitHub |
|------|------|--------|
| Dancer2::Template::Xslate | [Link](https://metacpan.org/module/Dancer2::Template::Xslate) | [Link](https://github.com/rsimoes/Dancer2-Template-Xslate) |
| Dancer2::Template::MojoTemplate | [Link](https://metacpan.org/module/Dancer2::Template::MojoTemplate) | [Link](https://github.com/VeroLom/Dancer2-Template-MojoTemplate) |
| Dancer2::Template::Caribou | [Link](https://metacpan.org/module/Dancer2::Template::Caribou) | [Link](https://github.com/yanick/Dancer2-Template-Caribou) |


## License

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
