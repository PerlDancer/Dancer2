# NAME

Dancer2 - Lightweight yet powerful web application framework

# VERSION

version 0.400001

# DESCRIPTION

Dancer2 is the new generation of [Dancer](https://metacpan.org/pod/Dancer), the lightweight web-framework for
Perl. Dancer2 is a complete rewrite based on [Moo](https://metacpan.org/pod/Moo).

Dancer2 can optionally use XS modules for speed, but at its core remains
fatpackable (packable by [App::FatPacker](https://metacpan.org/pod/App%3A%3AFatPacker)) so you could easily deploy Dancer2
applications on hosts that do not support custom CPAN modules.

Dancer2 is easy and fun:

    use Dancer2;
    get '/' => sub { "Hello World" };
    dance; 

This is the main module for the Dancer2 distribution. It contains logic for
creating a new Dancer2 application.

## Documentation Index

Documentation on Dancer2 is split into several sections. Below is a
complete outline on where to go for help.

- Dancer2 Tutorial

    If you are new to the Dancer approach, you should start by reading
    our [Dancer2::Tutorial](https://metacpan.org/pod/Dancer2%3A%3ATutorial).

- Dancer2 Manual

    [Dancer2::Manual](https://metacpan.org/pod/Dancer2%3A%3AManual) is the reference for Dancer2. Here you will find
    information on the concepts of Dancer2 application development and
    a comprehensive reference to the Dancer2 domain specific
    language.

- Dancer2 Keywords

    The keywords for Dancer2 can be found under [DSL Keywords](https://metacpan.org/pod/Dancer2%3A%3AManual#DSL-KEYWORDS).

- Dancer2 Deployment

    For configuration examples of different deployment solutions involving
    Dancer2 and Plack, refer to [Dancer2::Manual::Deployment](https://metacpan.org/pod/Dancer2%3A%3AManual%3A%3ADeployment).

- Dancer2 Cookbook

    Specific examples of code for real-life problems and some 'tricks' for
    applications in Dancer can be found in [Dancer2::Cookbook](https://metacpan.org/pod/Dancer2%3A%3ACookbook)

- Dancer2 Config

    For configuration file details refer to [Dancer2::Config](https://metacpan.org/pod/Dancer2%3A%3AConfig). It is a
    complete list of all configuration options.

- Dancer2 Plugins

    Refer to [Dancer2::Plugins](https://metacpan.org/pod/Dancer2%3A%3APlugins) for a partial list of available Dancer2
    plugins. Note that although we try to keep this list up to date we
    expect plugin authors to tell us about new modules.

    For information on how to author a plugin, see ["Writing the plugin" in Dancer2::Plugin](https://metacpan.org/pod/Dancer2%3A%3APlugin#Writing-the-plugin).

- Dancer2 Migration guide

    [Dancer2::Manual::Migration](https://metacpan.org/pod/Dancer2%3A%3AManual%3A%3AMigration) provides the most up-to-date instruction on
    how to convert a Dancer (1) based application to Dancer2.

### Other Documentation

- Core and Community Policy, and Standards of Conduct

    The ["Dancer core and community policy, and standards of conduct"](#dancer-core-and-community-policy-and-standards-of-conduct) defines
    what constitutes acceptable behavior in our community, what behavior is considered
    abusive and unacceptable, and what steps will be taken to remediate inappropriate
    and abusive behavior. By participating in any public forum for Dancer or its
    community, you are agreeing to the terms of this policy.

- GitHub Wiki

    Our [GitHub wiki](https://github.com/PerlDancer/Dancer2/wiki) has community-contributed
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

# FUNCTIONS

## my $runner=runner();

Returns the current runner. It is of type [Dancer2::Core::Runner](https://metacpan.org/pod/Dancer2%3A%3ACore%3A%3ARunner).

# SECURITY REPORTS

If you need to report a security vulnerability in Dancer2, send all pertinent
information to [mailto:dancer-security@dancer.pm](mailto:dancer-security@dancer.pm). These matters are taken
extremely seriously, and will be addressed in the earliest timeframe possible.

# SUPPORT

You are welcome to join our mailing list.
For subscription information, mail address and archives see
[http://lists.preshweb.co.uk/mailman/listinfo/dancer-users](http://lists.preshweb.co.uk/mailman/listinfo/dancer-users).

We are also on IRC: #dancer on irc.perl.org.

# AUTHORS

## CORE DEVELOPERS

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

## CORE DEVELOPERS EMERITUS

    David Golden
    Steven Humphrey

## CONTRIBUTORS

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

# AUTHOR

Dancer Core Developers

# COPYRIGHT AND LICENSE

This software is copyright (c) 2023 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
