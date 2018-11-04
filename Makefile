SHELL := /bin/bash

DOCTYPE  := rsd
COMPILE_CMD_LOCAL := bundle exec metanorma -t $(DOCTYPE) -x xml,pdf,html,doc $$FILENAME
COMPILE_CMD_DOCKER := docker run -v "$$(pwd)":/metanorma/ ribose/metanorma "metanorma -t $(DOCTYPE) -x xml,pdf,html,doc $$FILENAME"

ifdef METANORMA_DOCKER
  COMPILE_CMD := echo "Compiling via docker..."; $(COMPILE_CMD_DOCKER)
else
  COMPILE_CMD := echo "Compiling locally"; $(COMPILE_CMD_LOCAL)
endif

SRC := $(wildcard ${DOCTYPE}-*.adoc)
XML  := $(patsubst %.adoc,%.xml,$(SRC))
HTML := $(patsubst %.adoc,%.html,$(SRC))
DOC  := $(patsubst %.adoc,%.doc,$(SRC))
PDF  := $(patsubst %.adoc,%.pdf,$(SRC))

FORMATS := html doc xml pdf

_OUT_FILES := $(foreach FORMAT,$(FORMATS),$(shell echo $(FORMAT) | tr '[:lower:]' '[:upper:]'))
OUT_FILES  := $(foreach F,$(_OUT_FILES),$($F))

all: $(OUT_FILES)

%.xml %.html %.doc %.pdf:	%.adoc | bundle
	FILENAME=$^; \
	${COMPILE_CMD}

define FORMAT_TASKS
OUT_FILES-$(FORMAT) := $($(shell echo $(FORMAT) | tr '[:lower:]' '[:upper:]'))

open-$(FORMAT):
	open $$(OUT_FILES-$(FORMAT))

clean-$(FORMAT):
	rm -f $$(OUT_FILES-$(FORMAT))

$(FORMAT): clean-$(FORMAT) $$(OUT_FILES-$(FORMAT))

.PHONY: clean-$(FORMAT)

endef

$(foreach FORMAT,$(FORMATS),$(eval $(FORMAT_TASKS)))

# open: $(foreach FORMAT,$(FORMATS),open-$(FORMAT))

open: open-html

clean:
	rm -f $(OUT_FILES)

bundle:
	bundle

.PHONY: bundle all open clean

#
# Watch-related jobs
#

.PHONY: watch serve watch-serve

NODE_BINS          := onchange live-serve run-p
NODE_BIN_DIR       := node_modules/.bin
NODE_PACKAGE_PATHS := $(foreach PACKAGE_NAME,$(NODE_BINS),$(NODE_BIN_DIR)/$(PACKAGE_NAME))

$(NODE_PACKAGE_PATHS): package.json
	npm i

watch: $(NODE_BIN_DIR)/onchange
	make all
	$< $(ALL_SRC) -- make all

define WATCH_TASKS
watch-$(FORMAT): $(NODE_BIN_DIR)/onchange
	make $(FORMAT)
	$$< $$(SRC_$(FORMAT)) -- make $(FORMAT)

.PHONY: watch-$(FORMAT)
endef

$(foreach FORMAT,$(FORMATS),$(eval $(WATCH_TASKS)))

serve: $(NODE_BIN_DIR)/live-server revealjs-css reveal.js images
	export PORT=$${PORT:-8123} ; \
	port=$${PORT} ; \
	for html in $(HTML); do \
		$< --entry-file=$$html --port=$${port} --ignore="*.html,*.xml,Makefile,Gemfile.*,package.*.json" --wait=1000 & \
		port=$$(( port++ )) ;\
	done

watch-serve: $(NODE_BIN_DIR)/run-p
	$< watch serve

#
# Deploy jobs
#

publish:
	mkdir -p published
	cp -a $(OUT_FILES) images published/
	cp $(firstword $(HTML)) published/index.html
