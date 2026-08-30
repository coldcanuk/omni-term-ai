# POSIX-friendly install rules. GNU and BSD make both accept this subset.
PREFIX ?= /usr/local
DESTDIR ?=
BINDIR = $(PREFIX)/bin
DATADIR = $(PREFIX)/share/omni-term-ai
APPDIR = $(PREFIX)/share/applications
ICONDIR = $(PREFIX)/share/icons/hicolor/scalable/apps
MANDIR = $(PREFIX)/share/man/man1
DOCDIR = $(PREFIX)/share/doc/omni-term-ai
INSTALL ?= install

OMNI_HOME_VALUE = $(PREFIX)/share/omni-term-ai

all:
	@echo "Nothing to build. Use: make install PREFIX=$(PREFIX)"

install:
	$(INSTALL) -d $(DESTDIR)$(BINDIR)
	$(INSTALL) -d $(DESTDIR)$(DATADIR)/lib
	$(INSTALL) -d $(DESTDIR)$(DATADIR)/nvim-config
	$(INSTALL) -d $(DESTDIR)$(DATADIR)/nvim-config/lua
	$(INSTALL) -d $(DESTDIR)$(APPDIR)
	$(INSTALL) -d $(DESTDIR)$(ICONDIR)
	$(INSTALL) -d $(DESTDIR)$(MANDIR)
	$(INSTALL) -d $(DESTDIR)$(DOCDIR)
	$(INSTALL) -m 644 lib/omni.sh $(DESTDIR)$(DATADIR)/lib/omni.sh
	sed "s|@OMNI_HOME@|$(OMNI_HOME_VALUE)|g" lib/omni-bash.sh > $(DESTDIR)$(DATADIR)/lib/omni-bash.sh
	chmod 644 $(DESTDIR)$(DATADIR)/lib/omni-bash.sh
	$(INSTALL) -m 644 lib/deepseek-completion.bash $(DESTDIR)$(DATADIR)/lib/deepseek-completion.bash
	sed "s|@OMNI_HOME@|$(OMNI_HOME_VALUE)|g" lib/boot.sh > $(DESTDIR)$(DATADIR)/lib/boot.sh
	chmod 644 $(DESTDIR)$(DATADIR)/lib/boot.sh
	$(INSTALL) -m 644 tmux.conf $(DESTDIR)$(DATADIR)/tmux.conf
	$(INSTALL) -m 644 nvim-config/init.lua $(DESTDIR)$(DATADIR)/nvim-config/init.lua
	$(INSTALL) -m 644 nvim-config/lua/omni_fim.lua $(DESTDIR)$(DATADIR)/nvim-config/lua/omni_fim.lua
	if [ -f nvim-config/lazy-lock.json ]; then \
		$(INSTALL) -m 644 nvim-config/lazy-lock.json $(DESTDIR)$(DATADIR)/nvim-config/lazy-lock.json; \
	fi
	$(INSTALL) -m 644 ai-workspace.desktop $(DESTDIR)$(APPDIR)/ai-workspace.desktop
	$(INSTALL) -m 644 brain.svg $(DESTDIR)$(ICONDIR)/ai-workspace.svg
	$(INSTALL) -m 644 man/launch-ai-workspace.1 $(DESTDIR)$(MANDIR)/launch-ai-workspace.1
	$(INSTALL) -m 644 man/omni-config.1 $(DESTDIR)$(MANDIR)/omni-config.1
	$(INSTALL) -m 644 README.md $(DESTDIR)$(DOCDIR)/README.md
	$(INSTALL) -m 644 LICENSE $(DESTDIR)$(DOCDIR)/LICENSE
	sed "s|@OMNI_HOME@|$(OMNI_HOME_VALUE)|g" launch-ai-workspace > $(DESTDIR)$(BINDIR)/launch-ai-workspace
	sed "s|@OMNI_HOME@|$(OMNI_HOME_VALUE)|g" omni-exec.sh > $(DESTDIR)$(BINDIR)/omni-exec
	sed "s|@OMNI_HOME@|$(OMNI_HOME_VALUE)|g" omni-secret > $(DESTDIR)$(BINDIR)/omni-secret
	sed "s|@OMNI_HOME@|$(OMNI_HOME_VALUE)|g" omni-config > $(DESTDIR)$(BINDIR)/omni-config
	chmod 755 $(DESTDIR)$(BINDIR)/launch-ai-workspace $(DESTDIR)$(BINDIR)/omni-exec $(DESTDIR)$(BINDIR)/omni-secret $(DESTDIR)$(BINDIR)/omni-config
	$(INSTALL) -m 755 tmux-toggle-scratch $(DESTDIR)$(BINDIR)/tmux-toggle-scratch

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/launch-ai-workspace
	rm -f $(DESTDIR)$(BINDIR)/omni-exec
	rm -f $(DESTDIR)$(BINDIR)/omni-secret
	rm -f $(DESTDIR)$(BINDIR)/omni-config
	rm -f $(DESTDIR)$(BINDIR)/tmux-toggle-scratch
	rm -f $(DESTDIR)$(APPDIR)/ai-workspace.desktop
	rm -f $(DESTDIR)$(ICONDIR)/ai-workspace.svg
	rm -f $(DESTDIR)$(MANDIR)/launch-ai-workspace.1
	rm -rf $(DESTDIR)$(DATADIR)
	rm -rf $(DESTDIR)$(DOCDIR)

test:
	sh packaging/tests/verify-install.sh

deb:
	sh packaging/build-deb.sh

rpm:
	sh packaging/build-rpm.sh
