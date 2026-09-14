BINARY      := .build/release/Passkey
ENTITLEMENTS := passkey.entitlements
PREFIX      ?= /usr/local/bin

# Ad-hoc signing works for local use.
# For a Developer ID signature: make IDENTITY="Developer ID Application: You (TEAMID)"
# For Hardened Runtime (required for notarization): add --options runtime to the codesign call below.
IDENTITY    ?= -

.PHONY: all build sign install uninstall clean

all: sign

build:
	swift build -c release 2>&1

sign: build
	codesign --force \
	         --sign "$(IDENTITY)" \
	         --entitlements "$(ENTITLEMENTS)" \
	         "$(BINARY)"
	@echo "signed: $(BINARY)"

install: sign
	install -d "$(PREFIX)"
	install -m 0755 "$(BINARY)" "$(PREFIX)/passkey"
	@echo "installed: $(PREFIX)/passkey"

uninstall:
	rm -f "$(PREFIX)/passkey"
	@echo "removed: $(PREFIX)/passkey"

clean:
	swift package clean
