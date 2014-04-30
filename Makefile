.if exists(build/hooks/Makefile)
.include "build/hooks/Makefile"
.endif

NANO_LABEL?=FreeNAS
VERSION?=9.2.2-ALPHA
BUILD_TIMESTAMP!=date '+%Y%m%d'
COMPANY?="iXsystems"

.ifdef SCRIPT
RELEASE_LOGFILE?=${SCRIPT}
.else
RELEASE_LOGFILE?=release.build.log
.endif

GIT_REPO_SETTING=.git-repo-setting
.if exists(${GIT_REPO_SETTING})
GIT_LOCATION!=cat ${GIT_REPO_SETTING}
.endif
ENV_SETUP=env NANO_LABEL=${NANO_LABEL} VERSION=${VERSION} GIT_LOCATION=${GIT_LOCATION} BUILD_TIMESTAMP=${BUILD_TIMESTAMP}

USE_POUDRIERE=yes
.if defined(USE_POUDRIERE)
ENV_SETUP+= USE_POUDRIERE=${USE_POUDRIERE}
.endif

all:	build

.BEGIN:
	${ENV_SETUP} build/check_build_host.sh
	${ENV_SETUP} build/check_sandbox.sh

build: git-verify
	@[ `id -u` -eq 0 ] || (echo "Sorry, you must be running as root to build this."; exit 1)
.if defined(USE_POUDRIERE)
	@${ENV_SETUP} ${MAKE} portsjail
	@${ENV_SETUP} ${MAKE} ports
.else
	${ENV_SETUP} PACKAGE_PREP_BUILD=1 build/do_build.sh
.endif
	${ENV_SETUP} build/do_build.sh

checkout: git-verify
	${ENV_SETUP} build/do_checkout.sh

update: checkout

clean:
	${ENV_SETUP} build/build_cleanup.py
	rm -rf ${NANO_LABEL}-${VERSION}-* release.build.log
.if defined(USE_NEW_LAYOUT)
	rm -rf ../obj
.else
	rm -rf FreeBSD nas_source
.endif

clean-packages:
.if defined(USE_NEW_LAYOUT)
	find ../obj/os-base -name "*.tbz" -delete
.else
	find os-base -name "*.tbz" -delete
.endif

distclean: clean
.if defined(USE_NEW_LAYOUT)
	rm -fr ../extra-src
.endif

save-build-env:
	${ENV_SETUP} build/save_build.sh

freenas: release
release: git-verify
	${ENV_SETUP} build/check_build_host.sh
	${ENV_SETUP} build/check_sandbox.sh
	@echo "Doing executing target $@ on host: `hostname`"
	@echo "Build directory: `pwd`"
.if defined(USE_POUDRIERE)
	${ENV_SETUP} script -a ${RELEASE_LOGFILE} ${MAKE} build
	${ENV_SETUP} script -a ${RELEASE_LOGFILE} build/create_release_distribution.sh
.else
	${ENV_SETUP} script -a ${RELEASE_LOGFILE} build/build_release.sh
.endif

rebuild:
	@${ENV_SETUP} ${MAKE} checkout
	@${ENV_SETUP} ${MAKE} all
	@${ENV_SETUP) sh build/create_release_distribution.sh

cdrom:
	${ENV_SETUP} sh -x build/create_iso.sh

truenas: git-verify
	@[ "${GIT_LOCATION}" = "INTERNAL" ] || (echo "You can only run this target from an internal repository."; exit 1)
	env NANO_LABEL=TrueNAS script -a ${RELEASE_LOGFILE} ${MAKE} build
	mkdir -p TrueNAS-${VERSION}-${BUILD_TIMESTAMP}
.if defined(USE_NEW_LAYOUT)
	mv ../obj/os-base/amd64/TrueNAS-${VERSION}-* TrueNAS-${VERSION}-${BUILD_TIMESTAMP}
.else
	mv os-base/amd64/TrueNAS-${VERSION}-* TrueNAS-${VERSION}-${BUILD_TIMESTAMP}
.endif

# Build truenas using all sources 
truenas-all-direct:
	${ENV_SETUP} TESTING_TRUENAS=1 NAS_PORTS_DIRECT=1 $(MAKE) all

# intentionally split up to prevent abuse/spam
BUILD_BUG_DOMAIN?=ixsystems.com
BUILD_BUG_USER?=build-bugs
BUILD_BUG_EMAIL?=${BUILD_BUG_USER}@${BUILD_BUG_DOMAIN}

build-bug-report:
	mail -s "build fail for $${SUDO_USER:-$$USER}" ${BUILD_BUG_EMAIL} < \
		${RELEASE_LOGFILE}

git-verify:
	@if [ ! -f ${GIT_REPO_SETTING} ]; then \
		echo "No git repo choice is set.  Please use \"make git-external\" to build as an"; \
		echo "external developer or \"make git-internal\" to build as an ${COMPANY}"; \
		echo "internal developer.  You only need to do this once."; \
		exit 1; \
	fi
	@echo "NOTICE: You are building from the ${GIT_LOCATION} git repo."

git-internal:
	@echo "INTERNAL" > ${GIT_REPO_SETTING}
	@echo "You are set up for internal (${COMPANY}) development.  You can use"
	@echo "the standard make targets (e.g. build or release) now."

git-external:
	@echo "EXTERNAL" > ${GIT_REPO_SETTING}
	@echo "You are set up for external (github) development.  You can use"
	@echo "the standard make targets (e.g. build or release) now."

tag:
	${ENV_SETUP} build/apply_tag.sh

ports:
	@[ `id -u` -eq 0 ] || (echo "Sorry, you must be running as root to build this."; exit 1)
	${ENV_SETUP} build/check_build_host.sh
	${ENV_SETUP} build/check_sandbox.sh
	${ENV_SETUP} build/ports/create-poudriere-conf.sh
	${ENV_SETUP} build/ports/create-poudriere-make.conf.sh
	${ENV_SETUP} build/ports/prepare-jail.sh
	${ENV_SETUP} build/ports/fetch-ports-srcs.sh
	${ENV_SETUP} build/ports/create-ports-list.sh
	${ENV_SETUP} build/ports/build-ports.sh

portsjail:
	${ENV_SETUP} build/build_jail.sh
