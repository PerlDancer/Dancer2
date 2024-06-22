<p align="center">
  <a href="https://perldancer.org/">
    <img src="https://crome-plated.com/images/dancer-logo.png" alt="Perl Dancer logo">
  </a>
</p>

<p align="center">
  Dancer2 is a lightweight yet powerful web application framework
  written in Perl.
  <br>
  <a href="https://metacpan.org/pod/Dancer2%3A%3ATutorial">Tutorial</a>
  ·
  <a href="https://metacpan.org/pod/Dancer2%3A%3AManual">Manual</a>
  ·
  <a href="https://github.com/PerlDancer/Dancer2/discussions">Discussion Forums</a>
  ·
  <a href="https://github.com/PerlDancer/Dancer2/wiki">Public Wiki</a>
  ·
  <a href="http://lists.preshweb.co.uk/mailman/listinfo/dancer-users">Mailing List</a>
</p><br>

Dancer2 is the evolution of [Dancer](https://metacpan.org/pod/Dancer)
which is based on on [Moo](https://metacpan.org/pod/Moo), a lightweight
object framework for Perl.

Dancer2 can optionally use XS modules for speed, but at its core remains
fatpackable (via [App::FatPacker](https://metacpan.org/pod/App%3A%3AFatPacker)), allowing
you to easily deploy Dancer2 applications in environments that do not support custom
installations of CPAN modules.

Dancer2 is easy and fun:

    use Dancer2;
    get '/' => sub { "Hello World" };
    dance;

## Documentation Index

Documentation for Dancer2 is split into several sections:

- Dancer2 Tutorial

    If you've never danced before, you should start by reading
    our [tutorial](https://metacpan.org/pod/Dancer2%3A%3ATutorial).

- Manual

    The [Dancer2::Manual](https://metacpan.org/pod/Dancer2%3A%3AManual) is the definitive reference for Dancer2. Here you will find
    information on the concepts of Dancer2 application development and a comprehensive reference to the Dancer2 domain specific
    language.

- Keyword Guide

    The complete list of keywords for Dancer2 is documented in the [DSL Keywords](https://metacpan.org/pod/Dancer2%3A%3AManual#DSL-KEYWORDS)
    guide.

- Deployment

    For configuration examples of different deployment solutions involving
    Dancer2 and Plack, refer to [the deployment guide](https://metacpan.org/pod/Dancer2%3A%3AManual%3A%3ADeployment).

- Cookbook

    Specific examples of code for real-life problems and some 'tricks' for
    applications in Dancer2 can be found in [the Cookbook](https://metacpan.org/pod/Dancer2%3A%3ACookbook)

- Configuration

    For configuration file details refer to [Dancer2::Config](https://metacpan.org/pod/Dancer2%3A%3AConfig). It is a
    complete list of all configuration options.

- Plugins

    Refer to [Dancer2::Plugins](https://metacpan.org/pod/Dancer2%3A%3APlugins) for a curated list of Dancer2
    plugins, or [search MetaCPAN](https://metacpan.org/search?q=Dancer2%3A%3APlugin) for a complete list.

    For information on how to author a plugin, see ["Writing the plugin" in Dancer2::Plugin](https://metacpan.org/pod/Dancer2%3A%3APlugin#Writing-the-plugin).

- Dancer2 Migration Guide

    [The migration guide](https://metacpan.org/pod/Dancer2%3A%3AManual%3A%3AMigration) provides the most up-to-date instructions on
    how to convert a Dancer (1) based application to Dancer2.

### Other Documentation

- Core and Community Policy, and Standards of Conduct

    The [Dancer core and community policy, and standards of conduct](https://metacpan.org/pod/Dancer2%3A%3APolicy) defines
    what constitutes acceptable behavior in our community, what behavior is considered
    abusive and unacceptable, and what steps will be taken to remediate inappropriate
    and abusive behavior. By participating in any public forum for Dancer or its
    community, you are agreeing to the terms of this policy.

- GitHub Wiki

    Our [wiki](https://github.com/PerlDancer/Dancer2/wiki) has community-contributed
    documentation, as well as other information that doesn't quite fit within
    this manual.

- Contributing

    The [contribution guidelines](https://github.com/PerlDancer/Dancer2/blob/master/Contributing.md) describe
    how to set up your development environment to contribute to the development of Dancer2,
    Dancer2's Git workflow, submission guidelines, and various coding standards.

- Deprecation Policy

    The [deprecation policy](https://metacpan.org/pod/Dancer2%3A%3ADeprecationPolicy) defines the process for removing old,
    broken, unused, or outdated code from the Dancer2 codebase. This policy is critical
    for guiding and shaping future development of Dancer2.

# Security Reports

If you need to report a security vulnerability in Dancer2, send all pertinent
information to [dancer-security@dancer.pm](mailto:dancer-security@dancer.pm), or report it
via the GitHub security tool. These reports will be addressed in the earliest possible
timeframe.

# Support

You are welcome to join our mailing list.
For subscription information, mail address and archives see
[http://lists.preshweb.co.uk/mailman/listinfo/dancer-users](http://lists.preshweb.co.uk/mailman/listinfo/dancer-users).

We are also on IRC: #dancer on irc.perl.org.

# Authors

## Dancer Core Team

    Alberto Simões
    Alexis Sukrieh
    D Ruth Holloway (GeekRuthie)
    Damien Krotkine
    David Precious
    Franck Cuny
    Jason A. Crome
    Mickey Nasriachi
    Peter Mottram (SysPete)
    Russell Jenkins
    Sawyer X
    Stefan Hornburg (Racke)
    Yanick Champoux

## Core Team Emeritus

    David Golden
    Steven Humphrey

## Contributors

    A. Sinan Unur
    Abdullah Diab
    Achyut Kumar Panda
    Ahmad M. Zawawi
    Alex Beamish
    Alexander Karelas
    Alexander Pankoff
    Alexandr Ciornii
    Andrew Beverley
    Andrew Grangaard
    Andrew Inishev
    Andrew Solomon
    Andy Jack
    Ashvini V
    B10m
    Bas Bloemsaat
    baynes
    Ben Hutton
    Ben Kaufman
    biafra
    Blabos de Blebe
    Breno G. de Oliveira
    cdmalon
    Celogeek
    Cesare Gargano
    Charlie Gonzalez
    chenchen000
    Chi Trinh
    Christian Walde
    Christopher White
    cloveistaken
    Colin Kuskie
    cym0n
    Dale Gallagher
    Dan Book (Grinnz)
    Daniel Böhmer
    Daniel Muey
    Daniel Perrett
    Dave Jacoby
    Dave Webb
    David (sbts)
    David Steinbrunner
    David Zurborg
    Davs
    Deirdre Moran
    Dennis Lichtenthäler
    Dinis Rebolo
    dtcyganov
    Elliot Holden
    Emil Perhinschi
    Erik Smit
    Fayland Lam
    ferki
    Gabor Szabo
    GeekRuthie
    geistteufel
    Gideon D'souza
    Gil Magno
    Glenn Fowler
    Graham Knop
    Gregor Herrmann
    Grzegorz Rożniecki
    Hobbestigrou
    Hunter McMillen
    ice-lenor
    Ivan Bessarabov
    Ivan Kruglov
    JaHIY
    Jakob Voss
    James Aitken
    James Raspass
    James McCoy
    Jason Lewis
    Javier Rojas
    Jean Stebens
    Jens Rehsack
    Joel Berger
    Johannes Piehler
    Jonathan Cast
    Jonathan Scott Duff
    Joseph Frazer
    Julien Fiegehenn (simbabque)
    Julio Fraire
    Kaitlyn Parkhurst (SYMKAT)
    kbeyazli
    Keith Broughton
    lbeesley
    Lennart Hengstmengel
    Ludovic Tolhurst-Cleaver
    Mario Zieschang
    Mark A. Stratman
    Marketa Wachtlova
    Masaaki Saito
    Mateu X Hunter
    Matt Phillips
    Matt S Trout
    mauke
    Maurice
    MaxPerl
    Ma_Sys.ma
    Menno Blom
    Michael Kröll
    Michał Wojciechowski
    Mike Katasonov
    Mohammad S Anwar
    mokko
    Nick Patch
    Nick Tonkin
    Nigel Gregoire
    Nikita K
    Nuno Carvalho
    Olaf Alders
    Olivier Mengué
    Omar M. Othman
    pants
    Patrick Zimmermann
    Pau Amma
    Paul Clements
    Paul Cochrane
    Paul Williams
    Pedro Bruno
    Pedro Melo
    Philippe Bricout
    Ricardo Signes
    Rick Yakubowski
    Ruben Amortegui
    Sakshee Vijay (sakshee3)
    Sam Kington
    Samit Badle
    Sebastien Deseille (sdeseille)
    Sergiy Borodych
    Shlomi Fish
    Slava Goltser
    Snigdha
    Steve Bertrand
    Steve Dondley
    Steven Humphrey
    Tatsuhiko Miyagawa
    Timothy Alexis Vass
    Tina Müller
    Tom Hukins
    Upasana Shukla
    Utkarsh Gupta
    Vernon Lyon
    Victor Adam
    Vince Willems
    Vincent Bachelier
    xenu
    Yves Orton

# Author

Dancer Core Developers

# Copyright and License

This software is copyright (c) 2024 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
