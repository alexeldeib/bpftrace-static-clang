SHELL=/bin/bash -o pipefail

DOCKER ?= docker

.DEFAULT_GOAL := all

BPFTRACE_REF ?= "master"
OVERLAY_REF ?= "8fcc2a5676f9bea4ea6945f2cfdf52319ce7759c"
BCC_REF ?= "v0.12.0"
DOCKER_TAG ?= "quay.io/dalehamel/bpftrace-static-clang:latest"
DOCKER_TAG_CROSS ?= "quay.io/dalehamel/bpftrace-static-clang:cross"
DOCKER_TAG_BPFTRACE ?= "quay.io/dalehamel/bpftrace-static-clang:bpftrace"
CROSS_TARGET ?= "x86_64-multilib-linux-gnu"

.PHONY: cross
cross:
	${DOCKER} build -f docker/Dockerfile.cross \
                  -t $(DOCKER_TAG_CROSS) \
                  --build-arg overlay_ref=$(OVERLAY_REF) \
                  --build-arg bpftrace_ref=$(BPFTRACE_REF) \
                  --build-arg bcc_ref=$(BCC_REF) \
                  --build-arg cross_target=$(CROSS_TARGET) \
                  .

.PHONY: image/build
image/build:
	${DOCKER} build -f docker/Dockerfile.buildimage \
                  -t $(DOCKER_TAG) \
                  --build-arg overlay_ref=$(OVERLAY_REF) \
                  --build-arg bpftrace_ref=$(BPFTRACE_REF) \
                  --build-arg bcc_ref=$(BCC_REF) \
                  .

.PHONY: image/push
image/push:
	${DOCKER} push $(DOCKER_TAG)

.PHONY: image/pull
image/pull:
	${DOCKER} pull $(DOCKER_TAG)

bpftrace:
	${DOCKER} build -f docker/Dockerfile.bpftrace \
                  -t $(DOCKER_TAG_BPFTRACE) \
                  --build-arg bpftrace_ref=$(BPFTRACE_REF) \
                  .
	${DOCKER} run -v $$(pwd):/app -ti \
            $(DOCKER_TAG_BPFTRACE) \
            cp /usr/local/bin/bpftrace /app

.PHONY: login
login:
	echo "$$DOCKER_PASSWORD" | script -c bash -c "${DOCKER} login quay.io --username $$DOCKER_USER --password-stdin"

clean:
	rm -f bpftrace

all: build
