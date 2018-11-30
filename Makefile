.SUFFIXES:
.SUFFIXES: .go

.DEFAULT_GOAL: all

# make print-VAR would print the actual value for VAR
print-%: ;@echo $*=$($*)

# Go package name.
PKG := prometheus-nats-exporter

# Go expects lower case OS (darwin, linux) and x86_64 ARCH as amd64
# To cross-compile - override those on the fly, e.g. GOOS=linux GOARCH=amd64 make
HOST_GOOS := $(shell go env GOHOSTOS)
HOST_GOARCH := $(shell go env GOHOSTARCH)
HOST_TGT := $(HOST_GOOS)_$(HOST_GOARCH)
GOOS ?= $(HOST_GOOS)
GOARCH ?= $(HOST_GOARCH)
TGT := $(GOOS)_$(GOARCH)

BUILD_ID := $(shell git describe --long --always --tags --dirty)--$(shell git symbolic-ref -q --short HEAD)
BUILD_DATE := $(shell date -u +"%Y-%m-%d")
BUILD_TIME := $(shell date -u +"%H:%M:%S")
BUILD_USER := $(shell whoami)
BUILD_MACHINE := $(shell hostname)
LDFLAGS := -ldflags "-X main.buildID=${BUILD_ID} -X main.buildDate=${BUILD_DATE} -X main.buildTime=${BUILD_TIME} -X main.buildUser=${BUILD_USER} -X main.buildMachine=${BUILD_MACHINE}"

COMMANDS := prometheus_nats_exporter
CMD_BINARIES := $(COMMANDS:%=${TGT}/%)

RPM_OS := $(GOOS)
RPM_ARCH := $(subst amd64,x86_64,$(GOARCH))
RPM_VERSION := $(subst -,_,$(BUILD_ID))
RPM_VERSION := $(subst /,_,$(RPM_VERSION))
RPM_FILE := ${PKG}-${RPM_VERSION}-1.oc.${RPM_ARCH}.rpm

.PHONY: all
all: ${CMD_BINARIES}

ifeq ($(GOOS),linux)
rpm: ${RPM_FILE}
else
rpm:
	@echo 'RPM building is only supported for Linux targets.'
	@echo 'Hint: you can use GOOS and GOARCH to do a cross-compilation.'
endif

${RPM_FILE}: ${CMD_BINARIES} $(wildcard auxiliary/systemd/*.service)
	fpm -s dir -t rpm -f --rpm-os $(RPM_OS) -a ${RPM_ARCH} -n ${PKG} -v ${RPM_VERSION} --iteration 1.oc --epoch 1 ./${TGT}/=/usr/bin ./auxiliary/systemd/=/etc/systemd/system 

$(CMD_BINARIES): 
	go build ${LDFLAGS} -o $@ ${PKG}

.PHONY: clean
clean:
	rm -f ${CMD_BINARIES} 
ifeq ($(GOOS),linux)
	rm -f ${RPM_FILE}
endif
