PROJECT = Libmacgpg
TARGET = Libmacgpg
PRODUCT = Libmacgpg
PINENTRY_PATH = ./Dependencies/pinentry-mac
XPC_INSTALLATION_DIR = $(HOME)/Library/Application Support/GPGTools
VPATH = build/Release/Libmacgpg.framework/Versions/Current

all: $(PRODUCT)

update-pinentry:
	@echo "Updating pinentry..."
	@test -d "$(PINENTRY_PATH)/.git" || git submodule init
	git submodule update

update: update-pinentry

$(PRODUCT): Source/* Resources/* Resources/*/* Libmacgpg.xcodeproj
	@xcodebuild -project $(PROJECT).xcodeproj -target "$(PROJECT)" build $(XCCONFIG)
	@xcodebuild -project $(PROJECT).xcodeproj -target "org.gpgtools.Libmacgpg.xpc" build $(XCCONFIG) "XPC_INSTALLATION_DIR='$(XPC_INSTALLATION_DIR)'"

clean:
	rm -rf build/
	# Cleanup pinentry-mac if necessary.
	@test -d "$(PINENTRY_PATH)/build" && rm -rf "$(PINENTRY_PATH)/build" || exit 0
