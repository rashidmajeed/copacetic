# ------------------------------------------------------------
# Copyright (c) Project Copacetic authors.
# Licensed under the MIT License.
# ------------------------------------------------------------

################################################################################
# Global: Variables                                                            #
################################################################################

# Formatted symbol markers (=>, [needs root]) for info output
INFOMARK = $(shell printf "\033[34;1m=>\033[0m")
ROOTMARK = $(shell printf "\033[31;1m[needs root]\033[0m")

# Optional Make arguments
CGO_ENABLED ?= 0
CLI_VERSION ?= edge
DEBUG       ?= 0

# Go build metadata variables 
BASE_PACKAGE_NAME := github.com/project-copacetic/copacetic
GIT_COMMIT        := $(shell git rev-list -1 HEAD)
GIT_VERSION       := $(shell git describe --always --tags --dirty)
BUILD_DATE        := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
DEFAULT_LDFLAGS   := -X $(BASE_PACKAGE_NAME)/pkg/version.GitCommit=$(GIT_COMMIT) \
  -X $(BASE_PACKAGE_NAME)/pkg/version.GitVersion=$(GIT_VERSION) \
  -X $(BASE_PACKAGE_NAME)/pkg/version.BuildDate=$(BUILD_DATE) \
  -X main.version=$(CLI_VERSION)
GOARCH            := $(shell go env GOARCH)
GOOS              := $(shell go env GOOS)

# Message lack of native build support in Windows
ifeq ($(GOOS),windows)
  $(error Windows native build is unsupported, use WSL instead)
endif

# Build configuration variables
ifeq ($(DEBUG),0)
  BUILDTYPE_DIR:=release
  LDFLAGS:="$(DEFAULT_LDFLAGS) -s -w"
else
  BUILDTYPE_DIR:=debug
  LDFLAGS:="$(DEFAULT_LDFLAGS)"
  GCFLAGS:=-gcflags="all=-N -l"
  $(info $(INFOMARK) Build with debug information)
endif

# Build output variables
CLI_BINARY        := copa
OUT_DIR           := ./dist
BINS_OUT_DIR      := $(OUT_DIR)/$(GOOS)_$(GOARCH)/$(BUILDTYPE_DIR)

################################################################################
# Target: build (default action)                                               #
################################################################################
.PHONY: build
build: $(CLI_BINARY)

$(CLI_BINARY):
	$(info $(INFOMARK) Building $(CLI_BINARY) ...)
	CGO_ENABLED=$(CGO_ENABLED) GOOS=$(GOOS) GOARCH=$(GOARCH) \
	go build $(GCFLAGS) -ldflags $(LDFLAGS) -o $(BINS_OUT_DIR)/$(CLI_BINARY);

################################################################################
# Target: lint                                                                 #
################################################################################
.PHONY: lint
lint:
	$(info $(INFOMARK) Linting go code ...)
	golangci-lint run

################################################################################
# Target: format                                                               #
################################################################################
.PHONY: format
format:
	$(info $(INFOMARK) Formatting all go files with gofumpt ...)
	gofumpt -l -w .

################################################################################
# Target: archive                                                              #
################################################################################
ARCHIVE_OUT_DIR ?= $(BINS_OUT_DIR)
ARCHIVE_NAME = $(CLI_BINARY)_$(CLI_VERSION)_$(GOOS)_$(GOARCH).tar.gz
archive: $(ARCHIVE_NAME)
$(ARCHIVE_NAME):
	$(info $(INFOMARK) Building release package $(ARCHIVE_NAME) ...)
	chmod +x $(BINS_OUT_DIR)/$(CLI_BINARY)
	tar czf "$(ARCHIVE_OUT_DIR)/$(ARCHIVE_NAME)" -C "$(BINS_OUT_DIR)" "$(CLI_BINARY)"
	(cd $(ARCHIVE_OUT_DIR) && sha256sum -b "$(ARCHIVE_NAME)" > "$(ARCHIVE_NAME).sha256")

################################################################################
# Target: release                                                              #
################################################################################
.PHONY: release
release: build archive

################################################################################
# Target: test - unit testing                                                  #
################################################################################
.PHONY: test
test:
	$(info $(INFOMARK) Running unit tests on pkg libraries ...)
	go test ./pkg/...

################################################################################
# Target: clean                                                                #
################################################################################
.PHONY: clean
clean:
	$(info $(INFOMARK) Cleaning $(OUT_DIR) folder ...)
	rm -r $(OUT_DIR)

################################################################################
# Target: setup                                                                #
################################################################################
.PHONY: setup
setup:
	$(info $(INFOMARK) Installing Makefile go binary dependencies $(ROOTMARK) ...)
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install mvdan.cc/gofumpt@latest
