BUILDTAGS=

GIT_COMMIT := $(shell git rev-parse HEAD 2> /dev/null || true)
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2> /dev/null)

LDFLAGS := -X github.com/docker/containerd.GitCommit=${GIT_COMMIT} ${LDFLAGS}

# if this session isn't interactive, then we don't want to allocate a
# TTY, which would fail, but if it is interactive, we do want to attach
# so that the user can send e.g. ^C through.
INTERACTIVE := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE), 1)
	DOCKER_FLAGS += -t
endif

DOCKER_IMAGE := containerd-dev$(if $(GIT_BRANCH),:$(GIT_BRANCH))
DOCKER_RUN := docker run --rm -i $(DOCKER_FLAGS) "$(DOCKER_IMAGE)"

export GOPATH:=$(CURDIR)/vendor:$(GOPATH)

all: client daemon shim

static: client-static daemon-static shim-static

bin:
	mkdir -p bin/

clean:
	rm -rf bin

client: bin
	cd ctr && go build -ldflags "${LDFLAGS}" -o ../bin/ctr

client-static:
	cd ctr && go build -ldflags "-w -extldflags -static ${LDFLAGS}" -tags "$(BUILDTAGS)" -o ../bin/ctr

daemon: bin
	cd containerd && go build -ldflags "${LDFLAGS}"  -tags "$(BUILDTAGS)" -o ../bin/containerd

daemon-static:
	cd containerd && go build -ldflags "-w -extldflags -static ${LDFLAGS}" -tags "$(BUILDTAGS)" -o ../bin/containerd

shim: bin
	cd containerd-shim && go build -tags "$(BUILDTAGS)" -o ../bin/containerd-shim

shim-static:
	cd containerd-shim && go build -ldflags "-w -extldflags -static ${LDFLAGS}" -tags "$(BUILDTAGS)" -o ../bin/containerd-shim

dbuild:
	@docker build --rm --force-rm -t "$(DOCKER_IMAGE)" .

dtest: dbuild
	$(DOCKER_RUN) make test

install:
	cp bin/* /usr/local/bin/

protoc:
	protoc -I ./api/grpc/types ./api/grpc/types/api.proto --go_out=plugins=grpc:api/grpc/types

fmt:
	@gofmt -s -l . | grep -v vendor | grep -v .pb. | tee /dev/stderr

lint:
	@golint ./... | grep -v vendor | grep -v .pb. | tee /dev/stderr

shell: dbuild
	$(DOCKER_RUN) bash

test: all validate
	go test -v $(shell go list ./... | grep -v /vendor)

validate: fmt

vet:
	go vet $(shell go list ./... | grep -v vendor)
