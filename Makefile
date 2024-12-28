APPID := in.netroy.network-scanner
BUILD_DIR := build
FLATPAK_BUILD_DIR := flatpak-build-dir

.PHONY: all clean lint build install run flatpak-build flatpak-run flatpak-bundle

all: build

# Clean build directories
clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(FLATPAK_BUILD_DIR)
	rm -f $(APPID).flatpak

# Run linting
lint:
	io.elementary.vala-lint src

# Build using Meson
build:
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && meson setup ..
	cd $(BUILD_DIR) && ninja

# Install the application
install: build
	cd $(BUILD_DIR) && ninja install

# Run the application directly
run: build
	./$(BUILD_DIR)/network-scanner

# Build Flatpak
flatpak-build:
	flatpak-builder --force-clean $(FLATPAK_BUILD_DIR) $(APPID).yml

# Run Flatpak build
flatpak-run: flatpak-build
	flatpak-builder --run $(FLATPAK_BUILD_DIR) $(APPID).yml network-scanner

# Create Flatpak bundle
flatpak-bundle: flatpak-build
	flatpak-builder --repo=repo --force-clean $(FLATPAK_BUILD_DIR) $(APPID).yml
	flatpak build-bundle repo $(APPID).flatpak $(APPID)

# Development setup
setup:
	sudo pacman -S vala gtk4 meson base-devel flatpak flatpak-builder arp-scan libsoup json-glib
	flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
	yay -S vala-lint-git

# Show help
help:
	@echo "Available targets:"
	@echo "  make setup         - Install all dependencies"
	@echo "  make lint         - Run vala-lint"
	@echo "  make build        - Build the application"
	@echo "  make run          - Build and run the application"
	@echo "  make install      - Install the application"
	@echo "  make clean        - Clean build directories"
	@echo "  make flatpak-build - Build Flatpak"
	@echo "  make flatpak-run   - Run application in Flatpak"
	@echo "  make flatpak-bundle - Create Flatpak bundle"
