
HERE=${PWD}

PERLBREW_DIR=${HERE}/perlbrew
PERLBREW=export PERLBREW_ROOT=${PERLBREW_DIR} && source ${PERLBREW_DIR}/etc/bashrc && PERLBREW_ROOT=${PERLBREW_DIR} ${PERLBREW_DIR}/bin/perlbrew
CPANM_DANCER1=${PERLBREW} switch dancer1_plugin_tests && export PERLBREW_ROOT=${PERLBREW_DIR} && source ${PERLBREW_DIR}/etc/bashrc && PERLBREW_ROOT=${PERLBREW_DIR} ${PERLBREW_DIR}/bin/cpanm
CPANM_DANCER2=${PERLBREW} switch dancer2_plugin_tests && export PERLBREW_ROOT=${PERLBREW_DIR} && source ${PERLBREW_DIR}/etc/bashrc && PERLBREW_ROOT=${PERLBREW_DIR} ${PERLBREW_DIR}/bin/cpanm

all: got_curl got_bash got_perlbrew_perl
	${CPANM_DANCER1} --test-only --verbose Data::Dumper
	${CPANM_DANCER2} --test-only --verbose Data::Dumper

clean:
	rm -rf ${PERLBREW_DIR}

${PERLBREW_DIR}/bin/perlbrew:
	@echo " - creating a local perlbrew"
	export PERLBREW_ROOT=${PERLBREW_DIR} && curl -kL http://install.perlbrew.pl | bash

${PERLBREW_DIR}/bin/cpanm:
	${PERLBREW} install-cpanm

got_curl:
	@which curl >/dev/null || ( echo "you don't have curl, please install it and retry" && false )

got_bash:
	@which bash >/dev/null || ( echo "you don't have bash, please install it and retry" && false )

got_perlbrew_perl: ${PERLBREW_DIR}/bin/perlbrew ${PERLBREW_DIR}/bin/cpanm perlbrew_dancer1_plugin_tests perlbrew_dancer2_plugin_tests

perlbrew_dancer1_plugin_tests:
	@${PERLBREW} list | grep dancer1_plugin_tests > /dev/null || ( ${PERLBREW} install -j 2 -n perl-5.16.1 --as dancer1_plugin_tests )

perlbrew_dancer2_plugin_tests:
	@${PERLBREW} list | grep dancer1_plugin_tests > /dev/null || ( ${PERLBREW} install -j 2 -n perl-5.16.1 --as dancer2_plugin_tests )

