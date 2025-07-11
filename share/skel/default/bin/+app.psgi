#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";


# use this block if you don't need middleware, and only have a single target Dancer app to run here
use [d2% appname %2d];

[d2% appname %2d]->to_app;

=begin comment
# use this block if you want to include middleware such as Plack::Middleware::Deflater

use [d2% appname %2d];
use Plack::Builder;

builder {
    enable 'Deflater';
    [d2% appname %2d]->to_app;
}

=end comment

=cut

=begin comment
# use this block if you want to mount several applications on different path

use [d2% appname %2d];
use [d2% appname %2d]_admin;

use Plack::Builder;

builder {
    mount '/'      => [d2% appname %2d]->to_app;
    mount '/admin'      => [d2% appname %2d]_admin->to_app;
}

=end comment

=cut

