SHELL=/bin/bash -o pipefail

DOCKER ?= docker

.DEFAULT_GOAL := all

BPFTRACE_REF ?= "master"
OVERLAY_REF ?= "8fcc2a5676f9bea4ea6945f2cfdf52319ce7759c"
BCC_REF ?= "v0.12.0"

.PHONY: build
build:
	${DOCKER} build \
                  --build-arg overlay_ref=$(OVERLAY_REF) \
                  --build-arg bpftrace_ref=$(BPFTRACE_REF) \
                  --build-arg bcc_ref=$(BCC_REF) \
                  .

all: build
