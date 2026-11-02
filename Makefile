# Fixed TZ to ensure consistency
export TZ := UTC

WORKDIR=$(shell pwd)/workdir
IMAGE_VERSION ?= $(shell date -u +"%Y.%m.%d")

.PHONY: build test clean

build: 
	scripts/build-image.sh $(WORKDIR) $(IMAGE_VERSION)

test:
	scripts/test-image.sh $(WORKDIR) $(IMAGE_VERSION)

clean:
	rm -rf $(WORKDIR)
