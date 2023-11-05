BIN	= $(CURDIR)/bin
TEST	= $(CURDIR)/test

V = 0
Q = $(if $(filter 1,$V),,@)
M = $(shell printf "\033[34;1m▶\033[0m")

$(BIN)::
	@mkdir -p $@
