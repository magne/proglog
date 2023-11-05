include $(CURDIR)/include/go-rules.mk
include $(CURDIR)/include/proto-rules.mk

BUILD := $(CURDIR)/build
CERTS := $(BUILD)/cert

CONFIG_PATH := ${HOME}/.proglog

#
# Certificates
#
CA_DEPS := test/ca-config.json $(CONFIG_PATH)/ca.pem $(CONFIG_PATH)/ca-key.pem
CA_OPTS := -ca=$(CONFIG_PATH)/ca.pem -ca-key=$(CONFIG_PATH)/ca-key.pem -config=test/ca-config.json
CA_FILES := ca.pem ca-key.pem ca.csr
SERVER_FILES := server.pem server-key.pem server.csr
ROOT_CLIENT_FILES := root-client.pem root-client-key.pem root-client.csr
NOBODY_CLIENT_FILES := nobody-client.pem nobody-client-key.pem nobody-client.csr
CERT_FILES := $(addprefix $(CONFIG_PATH)/,$(CA_FILES) $(SERVER_FILES) $(ROOT_CLIENT_FILES) $(NOBODY_CLIENT_FILES))

CFSSL = $(BIN)/cfssl
$(BIN)/cfssl: PACKAGE=github.com/cloudflare/cfssl/cmd/cfssl@latest

CFSSLJSON = $(BIN)/cfssljson
$(BIN)/cfssljson: PACKAGE=github.com/cloudflare/cfssl/cmd/cfssljson@latest

$(CERTS)/ca.json: test/ca-csr.json | $(CFSSL) ; $(info $(M) create CA certificate)
	$Q mkdir -p $(@D)
	$Q $(CFSSL) gencert -loglevel=2 -initca $< > $@

$(CERTS)/server.json: test/server-csr.json $(CA_DEPS) | $(CFSSL) ; $(info $(M) create server certificate)
	$Q mkdir -p $(@D)
	$Q $(CFSSL) gencert -loglevel=2 $(CA_OPTS) -profile=server $< > $@

$(CERTS)/root-client.json: test/client-csr.json $(CA_DEPS) | $(CFSSL) ; $(info $(M) create root client certificate)
	$Q mkdir -p $(@D)
	$Q $(CFSSL) gencert -loglevel=2 $(CA_OPTS) -profile=client -cn="root" $< > $@

$(CERTS)/nobody-client.json: test/client-csr.json $(CA_DEPS) | $(CFSSL) ; $(info $(M) create nobody client certificate)
	$Q mkdir -p $(@D)
	$Q $(CFSSL) gencert -loglevel=2 $(CA_OPTS) -profile=client -cn="nobody" $< > $@

$(addprefix $(CONFIG_PATH)/,%.pem %-key.pem %.csr) &: $(CERTS)/%.json | $(CFSSLJSON)
	$Q mkdir -p $(@D)
	$Q $(CFSSLJSON) -bare -f $< $(@D)/$(basename $(<F))

#
# Config files
#
CONFIG_SOURCE := model.conf policy.csv
CONFIG_FILES := $(addprefix $(CONFIG_PATH)/,$(CONFIG_SOURCE))

$(CONFIG_FILES): $(CONFIG_PATH)/%: test/% ; $(info $(M) installing config file $<)
	$Q mkdir -p $(@D)
	$Q cp $< $@

#
# Protobuf
#
protoc-plugins:	$(BIN)/protoc-gen-go $(BIN)/protoc-gen-go-grpc
$(BIN)/protoc-gen-go: PACKAGE=google.golang.org/protobuf/cmd/protoc-gen-go@latest
$(BIN)/protoc-gen-go-grpc: PACKAGE=google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

PROTO_GO_FILES := \
		api/v1/log.pb.go \
		api/v1/log_grpc.pb.go

%.pb.go %_grpc.pb.go &: %.proto | $(PROTOC) protoc-plugins ; $(info $(M) compiling protobuf file $<)
	$Q $(PROTOC) $< \
		--go_out=. \
		--go-grpc_out=. \
		--go_opt=paths=source_relative \
		--go-grpc_opt=paths=source_relative \
		--proto_path=. \
		--proto_path=$(CURDIR)/include \
		--plugin=$(BIN)/protoc-gen-go \
		--plugin=$(BIN)/protoc-gen-go-grpc

compile: $(PROTO_GO_FILES)

test: $(PROTO_GO_FILES) $(CONFIG_FILES) $(CERT_FILES)
	go test -race ./...

clean: ; $(info $(M) cleaning…)
	$Q rm -f $(CURDIR)/api/v1/*.pb.go
	$Q rm -rf $(BUILD) $(CONFIG_PATH)

dist-clean: clean ; $(info $(M) dist cleaning…)
	$Q rm -rf $(BIN)
	$Q rm -rf $(CURDIR)/include/google

.PHONY: clean
