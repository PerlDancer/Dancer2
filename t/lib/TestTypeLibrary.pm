package TestTypeLibrary;
use Type::Library -base, -declare => ('MyDate');
use Type::Utils -all;
BEGIN { extends "Dancer2::Core::Types" };

declare MyDate, as StrMatch [qr{\d\d\d\d-\d\d-\d\d}];

1;
