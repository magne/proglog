BUILD := build
CERTS := $(BUILD)/cert

CONFIG_PATH := ${HOME}/.proglog

CONFIG_SOURCE := model.conf policy.csv
CONFIG_FILES := $(addprefix $(CONFIG_PATH)/,$(CONFIG_SOURCE))

CA_DEPS := test/ca-config.json $(CERTS)/ca.pem $(CERTS)/ca-key.pem
CA_OPTS := -ca=$(CERTS)/ca.pem -ca-key=$(CERTS)/ca-key.pem -config=test/ca-config.json
CA_FILES := ca.pem ca-key.pem ca.csr
SERVER_FILES := server.pem server-key.pem server.csr
ROOT_CLIENT_FILES := root-client.pem root-client-key.pem root-client.csr
NOBODY_CLIENT_FILES := nobody-client.pem nobody-client-key.pem nobody-client.csr
CERT_FILES := $(addprefix $(CONFIG_PATH)/,$(CA_FILES) $(SERVER_FILES) $(ROOT_CLIENT_FILES) $(NOBODY_CLIENT_FILES))


$(addprefix $(CERTS)/, $(CA_FILES)): test/ca-csr.json
	@mkdir -p $(@D)
	cfssl gencert -initca test/ca-csr.json | cfssljson -bare $(@D)/ca

$(addprefix $(CERTS)/, $(SERVER_FILES)): test/server-csr.json $(CA_DEPS)
	@mkdir -p $(@D)
	cfssl gencert $(CA_OPTS) -profile=server test/server-csr.json | cfssljson -bare $(@D)/server

$(addprefix $(CERTS)/, $(ROOT_CLIENT_FILES)): test/client-csr.json $(CA_DEPS)
	@mkdir -p $(@D)
	cfssl gencert $(CA_OPTS) -profile=client -cn="root" test/client-csr.json | cfssljson -bare $(@D)/root-client

$(addprefix $(CERTS)/, $(NOBODY_CLIENT_FILES)): test/client-csr.json $(CA_DEPS)
	@mkdir -p $(@D)
	cfssl gencert $(CA_OPTS) -profile=client -cn="nobody" test/client-csr.json | cfssljson -bare $(@D)/nobody-client

$(CONFIG_PATH)/%: $(CERTS)/%
	@mkdir -p $(@D)
	cp $< $@

$(CONFIG_FILES): $(CONFIG_PATH)/%: test/%
	@mkdir -p $(@D)
	cp $< $@

.PHONY: compile
compile:
	protoc api/v1/*.proto \
		--go_out=. \
		--go-grpc_out=. \
		--go_opt=paths=source_relative \
		--go-grpc_opt=paths=source_relative \
		--proto_path=.

test: $(CONFIG_FILES) $(CERT_FILES)
	go test -race ./...

clean:
	rm -rf $(BUILD) $(CONFIG_PATH)
	rm -f *.pem *.csr

.PHONY: clean
