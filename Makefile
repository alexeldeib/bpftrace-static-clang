SHELL=/bin/bash -o pipefail

DOCKER ?= docker

.DEFAULT_GOAL := all

BPFTRACE_REF ?= "master"
OVERLAY_REF ?= "8fcc2a5676f9bea4ea6945f2cfdf52319ce7759c"
BCC_REF ?= "v0.12.0"
DOCKER_TAG ?= "quay.io/dalehamel/bpftrace-static-clang:latest"

.PHONY: cross
cross:
	${DOCKER} build \
                  --build-arg overlay_ref=$(OVERLAY_REF) \
                  --build-arg bpftrace_ref=$(BPFTRACE_REF) \
                  --build-arg bcc_ref=$(BCC_REF) \
                  --build-arg cross_target=x86_64-nomultilib-linux-gnu \
                  cross

.PHONY: build
build:
	${DOCKER} build \
                  --build-arg overlay_ref=$(OVERLAY_REF) \
                  --build-arg bpftrace_ref=$(BPFTRACE_REF) \
                  --build-arg bcc_ref=$(BCC_REF) \
                  . -t $(DOCKER_TAG)

.PHONY: push
push:
	${DOCKER} push $(DOCKER_TAG)

.PHONY: pull
pull:
	${DOCKER} pull $(DOCKER_TAG)

.PHONY: login
login:
	echo "$$DOCKER_PASSWORD" | script -c bash -c "${DOCKER} login quay.io --username $$DOCKER_USER --password-stdin"

all: build
