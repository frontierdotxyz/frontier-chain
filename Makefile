#!/usr/bin/make -f

VERSION := $(shell echo $(shell git describe --tags) | sed 's/^v//')
COMMIT := $(shell git log -1 --format='%H')
LEDGER_ENABLED ?= true
export GO111MODULE = on

# process build tags

build_tags = netgo
ifeq ($(LEDGER_ENABLED),true)
  ifeq ($(OS),Windows_NT)
    GCCEXE = $(shell where gcc.exe 2> NUL)
    ifeq ($(GCCEXE),)
      $(error gcc.exe not installed for ledger support, please install or set LEDGER_ENABLED=false)
    else
      build_tags += ledger
    endif
  else
    UNAME_S = $(shell uname -s)
    ifeq ($(UNAME_S),OpenBSD)
      $(warning OpenBSD detected, disabling ledger support (https://github.com/cosmos/cosmos-sdk/issues/1988))
    else
      GCC = $(shell command -v gcc 2> /dev/null)
      ifeq ($(GCC),)
        $(error gcc not installed for ledger support, please install or set LEDGER_ENABLED=false)
      else
        build_tags += ledger
      endif
    endif
  endif
endif

ifeq ($(WITH_CLEVELDB),yes)
  build_tags += gcc
endif
build_tags += $(BUILD_TAGS)
build_tags := $(strip $(build_tags))

whitespace :=
whitespace += $(whitespace)
comma := ,
build_tags_comma_sep := $(subst $(whitespace),$(comma),$(build_tags))

# process linker flags

ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=frontierchain \
		  -X github.com/cosmos/cosmos-sdk/version.ServerName=frontd \
		  -X github.com/cosmos/cosmos-sdk/version.ClientName=frontcli \
		  -X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
		  -X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) \
		  -X "github.com/cosmos/cosmos-sdk/version.BuildTags=$(build_tags_comma_sep)"

ifeq ($(WITH_CLEVELDB),yes)
  ldflags += -X github.com/cosmos/cosmos-sdk/types.DBBackend=cleveldb
endif
ldflags += $(LDFLAGS)
ldflags := $(strip $(ldflags))

BUILD_FLAGS := -tags "$(build_tags)" -ldflags '$(ldflags)'


all: install

build: go.sum
ifeq ($(OS), Windows_NT)
	go build -mod=readonly $(BUILD_FLAGS) -o build/$(shell go env GOOS)/frontd.exe ./cmd/frontd
	go build -mod=readonly $(BUILD_FLAGS) -o build/$(shell go env GOOS)/frontcli.exe ./cmd/frontcli
else
	go build -mod=readonly $(BUILD_FLAGS) -o build/$(shell go env GOOS)/frontd ./cmd/frontd
	go build -mod=readonly $(BUILD_FLAGS) -o build/$(shell go env GOOS)/frontcli ./cmd/frontcli
endif

build-linux: go.sum
	LEDGER_ENABLED=false GOOS=linux GOARCH=amd64 $(MAKE) build

install: go.sum
	go install -mod=readonly $(BUILD_FLAGS) ./cmd/frontd
	go install -mod=readonly $(BUILD_FLAGS) ./cmd/frontcli

########################################
### Tools & dependencies

go-mod-cache: go.sum
	@echo "--> Download go modules to local cache"
	@go mod download
PHONY: go-mod-cache

go.sum: go.mod
	@echo "--> Ensuring dependencies have not been modified"
	@go mod verify

clean:
	rm -rf build/

########################################
### Linting

lint:
	golangci-lint run
	find . -name '*.go' -type f -not -path "./vendor*" -not -path "*.git*" | xargs gofmt -d -s
	go mod verify
.PHONY: lint

format:
	find . -name '*.go' -type f -not -path "./vendor*" -not -path "*.git*" -not -name '*.pb.go' | xargs gofmt -w -s
	find . -name '*.go' -type f -not -path "./vendor*" -not -path "*.git*" -not -name '*.pb.go' | xargs misspell -w
	find . -name '*.go' -type f -not -path "./vendor*" -not -path "*.git*" -not -name '*.pb.go' | xargs goimports -w -local github.com/tendermint
	find . -name '*.go' -type f -not -path "./vendor*" -not -path "*.git*" -not -name '*.pb.go' | xargs goimports -w -local github.com/cosmos/cosmos-sdk
	find . -name '*.go' -type f -not -path "./vendor*" -not -path "*.git*" -not -name '*.pb.go' | xargs goimports -w -local github.com/frontierdotxyz/frontier
.PHONY: format

########################################
### Testing

# build dependency needed for tests
test-all: build
	# basic app tests
	@go test ./app -v
	# basic simulation (seed "4" happens to not unbond all validators before reaching 100 blocks)
	@go test ./app -run TestFullAppSimulation        -Enabled -Commit -NumBlocks=100 -BlockSize=200 -Seed 4 -v -timeout 24h
	# other sim tests
	@go test ./app -run TestAppImportExport          -Enabled -Commit -NumBlocks=100 -BlockSize=200 -Seed 4 -v -timeout 24h
	@go test ./app -run TestAppSimulationAfterImport -Enabled -Commit -NumBlocks=100 -BlockSize=200 -Seed 4 -v -timeout 24h
	@# AppStateDeterminism does not use Seed flag
	@go test ./app -run TestAppStateDeterminism      -Enabled -Commit -NumBlocks=100 -BlockSize=200 -Seed 4 -v -timeout 24h

# run module tests and short simulations
test-basic: test
	@go test ./app -run TestFullAppSimulation        -Enabled -Commit -NumBlocks=5 -BlockSize=200 -Seed 4 -v -timeout 2m
	# other sim tests
	@go test ./app -run TestAppImportExport          -Enabled -Commit -NumBlocks=5 -BlockSize=200 -Seed 4 -v -timeout 2m
	@go test ./app -run TestAppSimulationAfterImport -Enabled -Commit -NumBlocks=5 -BlockSize=200 -Seed 4 -v -timeout 2m
	@# AppStateDeterminism does not use Seed flag
	@go test ./app -run TestAppStateDeterminism      -Enabled -Commit -NumBlocks=5 -BlockSize=200 -Seed 4 -v -timeout 2m

test:
	@go test $$(go list ./... | grep -v 'migrate\|contrib')

.PHONY: all build-linux install clean build test test-cli test-all test-basic
