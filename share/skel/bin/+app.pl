#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../lib";

use [% appname %];
[% appname %]->dance;
