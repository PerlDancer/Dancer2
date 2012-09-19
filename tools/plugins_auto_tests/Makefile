
HERE=${PWD}

PERLBREW_DIR=${HERE}/perlbrew
PERLBREW=export PERLBREW_ROOT=${PERLBREW_DIR} && source ${PERLBREW_DIR}/etc/bashrc && PERLBREW_ROOT=${PERLBREW_DIR} ${PERLBREW_DIR}/bin/perlbrew
CPANM_DANCER1=${PERLBREW} exec --with dancer1_plugin_tests ${PERLBREW_DIR}/bin/cpanm
CPANM_DANCER2=${PERLBREW} exec --with dancer2_plugin_tests ${PERLBREW_DIR}/bin/cpanm

all: got_curl got_bash got_perlbrew_perl plugins_list
	echo "Plugin name,Pass on Dancer 1,Pass on Dancer 2" > result.csv
	@for i in `cat plugins_list`; do pass_d1=0; pass_d2=0; \
	  echo " ---------- TESTING on Dancer 1 : $$i"; \
          ${CPANM_DANCER1} -n --installdeps $$i && ${CPANM_DANCER1} --test-only $$i && pass_d1=1; \
	  echo " ---------- TESTING on Dancer 2 : $$i"; \
          ${CPANM_DANCER2} -n --installdeps $$i && DANCER_FORCE_PLUGIN_REGISTRATION=1 ${CPANM_DANCER2} --test-only $$i && pass_d2=1; \
          echo "$$i,$$pass_d1,$$pass_d2" >> result.csv; \
        done;

clean:
	rm -rf plugins_list

fullclean:
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
	${PERLBREW} list | grep dancer1_plugin_tests > /dev/null || ( ${PERLBREW} install -j 2 -n perl-5.16.1 --as dancer1_plugin_tests )

perlbrew_dancer2_plugin_tests:
	${PERLBREW} list | grep dancer2_plugin_tests > /dev/null || ( ${PERLBREW} install -j 2 -n perl-5.16.1 --as dancer2_plugin_tests && ${CPANM_DANCER2} ${HERE}/../.. )

plugins_list:
	${HERE}/get_modules_list.pl > plugins_list
