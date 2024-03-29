# Makefile

# local config
SWIFT_BUILD=swift build
SWIFT_CLEAN=swift package clean
SWIFT_BUILD_DIR=.build
SWIFT_TEST=swift test
CONFIGURATION=release

# docker config
#SWIFT_BUILD_IMAGE="swift:5.7.2"
SWIFT_BUILD_IMAGE="helje5/arm64v8-swift-dev:5.5.3"
DOCKER_BUILD_DIR=".docker.build"
DOCKER_PLATFORM=aarch64
#DOCKER_PLATFORM="x86_64"
SWIFT_DOCKER_BUILD_DIR="$(DOCKER_BUILD_DIR)/$(DOCKER_PLATFORM)-unknown-linux/$(CONFIGURATION)"
DOCKER_BUILD_PRODUCT="$(DOCKER_BUILD_DIR)/$(TOOL_NAME)"

XENIAL_DESTINATION=/usr/local/lib/swift/dst/x86_64-unknown-linux/swift-5.3-ubuntu16.04.xtoolchain/destination.json
AWS_DESTINATION=/usr/local/lib/swift/dst/x86_64-unknown-linux/swift-5.2-amazonlinux2.xtoolchain/destination.json


SWIFT_SOURCES=\
	Sources/*/*/*.swift \
	Sources/*/*/*/*.swift

all:
	$(SWIFT_BUILD) -c $(CONFIGURATION)

# Cannot test in `release` configuration?!
test:
	$(SWIFT_TEST) 
	
clean :
	$(SWIFT_CLEAN)
	# We have a different definition of "clean", might be just German
	# pickyness.
	rm -rf $(SWIFT_BUILD_DIR) 


# Building for Linux

amazon-linux:
	$(SWIFT_BUILD) -c $(CONFIGURATION) --destination $(AWS_DESTINATION)

xc-xenial:
	$(SWIFT_BUILD) -c $(CONFIGURATION) --destination $(XENIAL_DESTINATION)

$(DOCKER_BUILD_PRODUCT): $(SWIFT_SOURCES)
	docker run --rm \
          -v "$(PWD):/src" \
          -v "$(PWD)/$(DOCKER_BUILD_DIR):/src/.build" \
          "$(SWIFT_BUILD_IMAGE)" \
          bash -c 'cd /src && swift build -c $(CONFIGURATION)'

docker-all: $(DOCKER_BUILD_PRODUCT)

docker-test: $(DOCKER_BUILD_PRODUCT)
	docker run --rm \
          -v "$(PWD):/src" \
          -v "$(PWD)/$(DOCKER_BUILD_DIR):/src/.build" \
          "$(SWIFT_BUILD_IMAGE)" \
          bash -c 'cd /src && swift test --enable-test-discovery -c $(CONFIGURATION)'

docker-clean:
	rm $(DOCKER_BUILD_PRODUCT)	
	
docker-distclean:
	rm -rf $(DOCKER_BUILD_DIR)

distclean: clean docker-distclean

docker-emacs:
	docker run --rm -it \
	          -v "$(PWD):/src" \
	          -v "$(PWD)/$(DOCKER_BUILD_DIR):/src/.build" \
	          "$(SWIFT_BUILD_IMAGE)" \
		  emacs /src
