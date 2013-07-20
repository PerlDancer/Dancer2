# Dancer2

[![Build Status](https://travis-ci.org/PerlDancer/Dancer2.png?branch=devel)](https://travis-ci.org/PerlDancer/Dancer2)

Dancer2 is the new generation lightweight web-framework for Perl. It's a complete rewrite of Dancer based on Moo.

Yes, you can use Dancer2 in production. It works. 

You can get more information about the Dancer project on the website: [`http://perldancer.org`](http://perldancer.org).

## Examples

An application can be as simple as this simple hello world script:

```perl
use Dancer2;
get '/' => sub { 
    "Hello World" 
};
dance;
```

## External resources

* [Most recent release on CPAN](https://metacpan.org/release/Dancer2)
* [Builds status on Travis](https://travis-ci.org/PerlDancer/Dancer2)
* [Follow us on Twitter](https://twitter.com/perldancer)
* [Find us on IRC](irc://irc.perl.org/#dancer)
* [The Advent Calendar](http://advent.perldancer.org/)
