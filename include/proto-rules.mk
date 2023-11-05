ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

include $(ROOT_DIR)/common.mk

PROTOC		= $(BIN)/protoc
PROTOC_VERSION	= 25.0

$(PROTOC): | $(BIN) ; $(info $(M) downloading protoc)
	$Q curl -Ls -o - \
		https://github.com/protocolbuffers/protobuf/releases/download/v$(PROTOC_VERSION)/protoc-$(PROTOC_VERSION)-linux-x86_64.zip \
		| busybox unzip -q - -x readme.txt -d $(CURDIR) \
		; chmod +x $(PROTOC)
