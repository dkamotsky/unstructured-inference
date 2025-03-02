PACKAGE_NAME := unstructured_inference
PIP_VERSION := 23.2.1
CURRENT_DIR := $(shell pwd)


.PHONY: help
help: Makefile
	@sed -n 's/^\(## \)\([a-zA-Z]\)/\2/p' $<


###########
# Install #
###########

## install-base:            installs core requirements needed for text processing bricks
.PHONY: install-base
install-base: install-base-pip-packages
	python3 -m pip install -r requirements/base.txt

## install:                 installs all test, dev, and experimental requirements
.PHONY: install
install: install-base-pip-packages install-dev

.PHONY: install-ci
install-ci: install-base-pip-packages install-test

.PHONY: install-base-pip-packages
install-base-pip-packages:
	python3 -m pip install pip==${PIP_VERSION}

.PHONY: install-test
install-test: install-base
	python3 -m pip install -r requirements/test.txt

.PHONY: install-dev
install-dev: install-test
	python3 -m pip install -r requirements/dev.txt

## pip-compile:             compiles all base/dev/test requirements
.PHONY: pip-compile
pip-compile:
	pip-compile --upgrade requirements/base.in
	pip-compile --upgrade requirements/test.in
	pip-compile --upgrade requirements/dev.in

#################
# Test and Lint #
#################

export CI ?= false

## test:                    runs all unittests
.PHONY: test
test:
	PYTHONPATH=. CI=$(CI) pytest -m "not slow" test_${PACKAGE_NAME} --cov=${PACKAGE_NAME} --cov-report term-missing

.PHONY: test-slow
test-slow:
	PYTHONPATH=. CI=$(CI) pytest test_${PACKAGE_NAME} --cov=${PACKAGE_NAME} --cov-report term-missing

## check:                   runs linters (includes tests)
.PHONY: check
check: check-src check-tests check-version

## check-src:               runs linters (source only, no tests)
.PHONY: check-src
check-src:
	ruff check ${PACKAGE_NAME} --line-length 100 --select C4,COM,E,F,I,PLR0402,PT,SIM,UP015,UP018,UP032,UP034 --ignore COM812,PT011,PT012,SIM117
	python -m black --line-length 100 ${PACKAGE_NAME} --check
	python -m flake8 ${PACKAGE_NAME}
	python -m mypy ${PACKAGE_NAME} --ignore-missing-imports

.PHONY: check-tests
check-tests:
	python -m black --line-length 100 test_${PACKAGE_NAME} --check
	python -m flake8 test_${PACKAGE_NAME}

## check-scripts:           run shellcheck
.PHONY: check-scripts
check-scripts:
    # Fail if any of these files have warnings
	scripts/shellcheck.sh

## check-version:           run check to ensure version in CHANGELOG.md matches version in package
.PHONY: check-version
check-version:
    # Fail if syncing version would produce changes
	scripts/version-sync.sh -c \
		-s CHANGELOG.md \
		-f unstructured_inference/__version__.py semver

## tidy:                    run black
.PHONY: tidy
tidy:
	ruff check ${PACKAGE_NAME} --fix --line-length 100 --select C4,COM,E,F,I,PLR0402,PT,SIM,UP015,UP018,UP032,UP034 --ignore COM812,PT011,PT012,SIM117
	black --line-length 100 ${PACKAGE_NAME}
	black --line-length 100 test_${PACKAGE_NAME}

## version-sync:            update __version__.py with most recent version from CHANGELOG.md
.PHONY: version-sync
version-sync:
	scripts/version-sync.sh \
		-s CHANGELOG.md \
		-f unstructured_inference/__version__.py semver

.PHONY: check-coverage
check-coverage:
	python -m coverage report --fail-under=95

##########
# Docker #
##########

# Docker targets are provided for convenience only and are not required in a standard development environment

DOCKER_IMAGE ?= unstructured-inference:dev

.PHONY: docker-build
docker-build:
	PIP_VERSION=${PIP_VERSION} DOCKER_IMAGE_NAME=${DOCKER_IMAGE} ./scripts/docker-build.sh

.PHONY: docker-test
docker-test: docker-build
	docker run --rm \
	-v ${CURRENT_DIR}/test_unstructured_inference:/home/test_unstructured_inference \
	-v ${CURRENT_DIR}/sample-docs:/home/sample-docs \
	$(DOCKER_IMAGE) \
	bash -c "pytest $(if $(TEST_NAME),-k $(TEST_NAME),) test_unstructured_inference"
