use Test::Whitespaces {

    dirs => [qw(
        lib
        script
        t
        tools
        xt
    )],

    ignore => [
        qr{t/sessions/},
    ],

};
