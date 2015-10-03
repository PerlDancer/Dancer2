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
        qr{t/template_tiny/samples},
    ],

};
