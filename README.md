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
* [How to contribute!](GitGuide.md)
* [Our Mailing List](http://list.perldancer.org/cgi-bin/listinfo/dancer-users)
* [Follow us on Twitter](https://twitter.com/perldancer)
* [Find us on irc.per.org #dancer](irc://irc.perl.org/#dancer)
* [The Advent Calendar](http://advent.perldancer.org/)

## List Of Available Plugins

| Name          | Type        | Link  |
| ------------- |-------------| ------|
| Dancer2::Session::Cookie | Session | [CPAN](https://metacpan.org/module/Dancer2::Session::Cookie) |
| Dancer2::Plugin::Syntax::GetPost | Syntactic sugar | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Syntax::GetPost) |
| Dancer2::Plugin::BrowserDetect | | [CPAN](https://metacpan.org/module/Dancer2::Plugin::BrowserDetect) |
| Dancer2::Plugin::RoutePodCoverage | Test | [CPAN](https://metacpan.org/module/Dancer2::Plugin::RoutePodCoverage) |
| Dancer2::Plugin::Auth::Tiny | Auth | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Auth::Tiny) |
| Dancer2::Plugin::Queue::MongoDB | Queue | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Queue::MongoDB) |
| Dancer2::Plugin::Paginator | Pagination | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Paginator) |
| Dancer2::Plugin::Deferred | Flash Message | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Deferred) |
| Dancer2::Plugin::Adapter | Class Wrapper | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Adapter) |
| Dancer2::Plugin::DBIC | Database | [CPAN](https://metacpan.org/module/Dancer2::Plugin::DBIC) |
| Dancer2::Plugin::REST | API | [CPAN](https://metacpan.org/module/Dancer2::Plugin::REST) |
| Dancer2::Plugin::Emailesque | Email | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Emailesque) |
| Dancer2::Plugin::Cache::CHI | Cache | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Cache::CHI) |
| Dancer2::Plugin::Queue | Queue | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Queue) |
| Dancer2::Plugin::Database | Database | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Database) |
| Dancer2::Plugin::Feed | Feed | [CPAN](https://metacpan.org/module/Dancer2::Plugin::Feed) |


## License

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
