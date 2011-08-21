perl Makefile.PL && make clean
perl Makefile.PL
make
cover -test -coverage=subroutine -coverage=branch
