PROJECT = GPGMail
TARGET = Free-GPGMail
PRODUCT = Free-GPGMail.mailbundle
VPATH = build/Release

all: $(PRODUCT)

$(PRODUCT): Source/* Resources/* Resources/*/* GPGMail.xcodeproj
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) build $(XCCONFIG)

clean:
	rm -rf "./build"
