.PHONY: build run release dist github-release

INFOPLIST := $(CURDIR)/Resources/Info.plist
LINK_INFOPLIST := -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker $(INFOPLIST)

build:
	swift build -c debug --product MagicLoupe $(LINK_INFOPLIST)
	bash scripts/package-app.sh debug

release:
	swift build -c release --product MagicLoupe $(LINK_INFOPLIST)
	bash scripts/package-app.sh release

run: build
	open "$$HOME/Applications/MagicLoupe.app"

# make dist VERSION=0.2.0
dist:
	bash scripts/release.sh $(VERSION)

# make github-release VERSION=0.2.0
github-release:
	bash scripts/release.sh $(VERSION) --github
