## Dancer2

Lightweight yet powerful web application framework.


### ABOUT

Dancer2 is the new generation of Dancer, the lightweight web-framework for
Perl. Dancer2 is a complete rewrite based on Moo.

Dancer2 can optionally use XS modules for speed, but at its core remains
fatpackable (packable by App::FatPacker) so you could easily deploy Dancer2
applications on hosts that do not support custom CPAN modules.


### EXAMPLE

```perl
use Dancer2;
get '/' => sub { "Hello World" };
dance;
```


### WEBSITE

For more details about the project, checkout the official website:
http://perldancer.org/ or checkout the documentation at
http://search.cpan.org/dist/Dancer2/

See also the Github project page: http://github.com/PerlDancer/Dancer2 for
the latest changes.


### REPORTING BUGS

Bug reports are appreciated and will receive prompt attention - the preferred
method is to raise them using Github's basic issue tracking system:

http://github.com/PerlDancer/Dancer2/issues


### CONTACT

You can reach the development team on IRC: irc://irc.perl.org/#dancer or
http://www.perldancer.org/irc for a web-based IRC client.

