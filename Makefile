PREFIX ?= /usr/local
INSTALL_DIR = $(PREFIX)/share/ubo
BIN_LINK = $(PREFIX)/bin/ubo

.PHONY: install uninstall test

install:
	@echo "Installing ubo to $(INSTALL_DIR)..."
	mkdir -p $(INSTALL_DIR)/bin $(INSTALL_DIR)/lib $(INSTALL_DIR)/resources
	cp bin/ubo $(INSTALL_DIR)/bin/
	cp lib/*.sh $(INSTALL_DIR)/lib/
	cp resources/*.applescript $(INSTALL_DIR)/resources/
	chmod +x $(INSTALL_DIR)/bin/ubo
	mkdir -p $(dir $(BIN_LINK))
	ln -sf $(INSTALL_DIR)/bin/ubo $(BIN_LINK)
	@echo ""
	@echo "Done! Run 'ubo install' to set up uBlock Origin."

uninstall:
	@echo "Removing ubo..."
	rm -f $(BIN_LINK)
	rm -rf $(INSTALL_DIR)
	@echo "Done. Run 'ubo uninstall' first if you haven't already."

test:
	@echo "Running basic checks..."
	@bash bin/ubo version
	@echo "Checking all lib scripts parse correctly..."
	@for f in lib/*.sh; do bash -n "$$f" && echo "  ✓ $$f"; done
	@echo "All checks passed."
