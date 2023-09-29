VERSION = 6.0.0
PN = anything-sync-daemon

PREFIX ?= /usr
CONFDIR = /etc
CRONDIR = /etc/cron.hourly
INITDIR_SYSTEMD = /usr/lib/systemd/system
INITDIR_SYSTEMD_SYSTEM = $(INITDIR_SYSTEMD)
INITDIR_SYSTEMD_USER = $(dir $(INITDIR_SYSTEMD))/user
INITDIR_UPSTART = /etc/init.d
BINDIR = $(PREFIX)/bin
DOCDIR = $(PREFIX)/share/doc/$(PN)
MANDIR = $(PREFIX)/share/man/man1
ZSHDIR = $(PREFIX)/share/zsh/site-functions
BSHDIR = $(PREFIX)/share/bash-completion/completions

# set to anything except 0 to enable manpage compression
COMPRESS_MAN = 1

# set to 1 to prevent attempting to stop asd before installation
SKIP_STOP = 0

PANDOC = pandoc
RM = rm
SED = sed
INSTALL = install -p
INSTALL_PROGRAM = $(INSTALL) -m755
INSTALL_SCRIPT = $(INSTALL) -m755
INSTALL_DATA = $(INSTALL) -m644
INSTALL_DIR = $(INSTALL) -d

Q = @

common/$(PN): Makefile common/$(PN).in
	$(Q)echo -e '\033[1;32mSetting version\033[0m'
	$(Q)$(SED) 's/@VERSION@/'$(VERSION)'/' common/$(PN).in > common/$(PN)

doc/asd.1: USAGE.md
	$(PANDOC) --standalone --from markdown+definition_lists+pandoc_title_block --to man -o $@ $<

help: install

stop-asd:
ifneq ($(SKIP_STOP),1)
ifneq ($(PREFIX), /usr)
	sudo -E asd unsync
endif
endif

disable-systemd:
ifneq ($(SKIP_STOP),1)
ifeq ($(PREFIX), /usr)
	systemctl stop asd asd-resync || :
endif
endif

install-bin: stop-asd disable-systemd common/$(PN)
	$(Q)echo -e '\033[1;32mInstalling main script...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(BINDIR)"
	$(INSTALL_PROGRAM) common/$(PN) "$(DESTDIR)$(BINDIR)/$(PN)"
	$(INSTALL_PROGRAM) common/asd-mount-helper "$(DESTDIR)$(BINDIR)/asd-mount-helper"
	ln -sf $(PN) "$(DESTDIR)$(BINDIR)/asd"
	cp -n common/asd.conf "$(DESTDIR)$(CONFDIR)/asd.conf"
	$(INSTALL_DIR) "$(DESTDIR)$(ZSHDIR)"
	$(INSTALL_DATA) common/zsh-completion "$(DESTDIR)/$(ZSHDIR)/_asd"
	$(INSTALL_DIR) "$(DESTDIR)$(BSHDIR)"
	$(INSTALL_DATA) common/bash-completion "$(DESTDIR)/$(BSHDIR)/asd"

install-man: doc/asd.1
	$(Q)echo -e '\033[1;32mInstalling manpage...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(MANDIR)"
	$(INSTALL_DATA) doc/asd.1 "$(DESTDIR)$(MANDIR)/asd.1"
ifneq ($(COMPRESS_MAN),0)
	gzip -9 "$(DESTDIR)$(MANDIR)/asd.1"
	ln -sf asd.1.gz "$(DESTDIR)$(MANDIR)/$(PN).1.gz"
else
	ln -sf asd.1 "$(DESTDIR)$(MANDIR)/$(PN).1"
endif

install-cron:
	$(Q)echo -e '\033[1;32mInstalling cronjob...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(CRONDIR)"
	$(INSTALL_SCRIPT) common/asd.cron.hourly "$(DESTDIR)$(CRONDIR)/asd-update"

install-systemd:
	$(Q)echo -e '\033[1;32mInstalling systemd files...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(CONFDIR)"
	$(INSTALL_DIR) "$(DESTDIR)$(INITDIR_SYSTEMD_SYSTEM)"
	$(INSTALL_DATA) init/asd.service "$(DESTDIR)$(INITDIR_SYSTEMD_SYSTEM)/asd.service"
	$(INSTALL_DATA) init/asd-resync.service "$(DESTDIR)$(INITDIR_SYSTEMD_SYSTEM)/asd-resync.service"
	$(INSTALL_DATA) init/asd-resync.timer "$(DESTDIR)$(INITDIR_SYSTEMD_SYSTEM)/asd-resync.timer"
	$(INSTALL_DIR) "$(DESTDIR)$(INITDIR_SYSTEMD_USER)"
	$(INSTALL_DATA) init/asd.service "$(DESTDIR)$(INITDIR_SYSTEMD_USER)/asd.service"
	$(INSTALL_DATA) init/asd-resync.service "$(DESTDIR)$(INITDIR_SYSTEMD_USER)/asd-resync.service"
	$(INSTALL_DATA) init/asd-resync.timer "$(DESTDIR)$(INITDIR_SYSTEMD_USER)/asd-resync.timer"

install-upstart:
	$(Q)echo -e '\033[1;32mInstalling upstart files...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(CONFDIR)"
	$(INSTALL_DIR) "$(DESTDIR)$(INITDIR_UPSTART)"
	$(INSTALL_SCRIPT) init/asd.upstart "$(DESTDIR)$(INITDIR_UPSTART)/asd"


install-systemd-all: install-bin install-man install-systemd

install-upstart-all: install-bin install-man install-cron install-upstart

install:
	$(Q)echo "run one of the following:"
	$(Q)echo "  make install-systemd-all (systemd based systems)"
	$(Q)echo "  make install-upstart-all (upstart based systems)"
	$(Q)echo
	$(Q)echo "or check out the Makefile for specific rules"

uninstall-bin:
	$(RM) "$(DESTDIR)$(BINDIR)/$(PN)"
	$(RM) "$(DESTDIR)$(BINDIR)/asd"
	$(RM) "$(DESTDIR)/$(BINDIR)/asd-mount-helper"
	$(RM) "$(DESTDIR)/$(ZSHDIR)/_asd"
	$(RM) "$(DESTDIR)/$(BSHDIR)/asd"

uninstall-man:
	$(RM) -f "$(DESTDIR)$(MANDIR)/$(PN).1.gz"
	$(RM) -f "$(DESTDIR)$(MANDIR)/asd.1.gz"
	$(RM) -f "$(DESTDIR)$(MANDIR)/$(PN).1"
	$(RM) -f "$(DESTDIR)$(MANDIR)/asd.1"

uninstall-cron:
	$(RM) "$(DESTDIR)$(CRONDIR)/asd-update"

uninstall-systemd:
	$(RM) "$(DESTDIR)$(CONFDIR)/asd.conf"
	$(RM) "$(DESTDIR)$(INITDIR_SYSTEMD_SYSTEM)/asd.service"
	$(RM) "$(DESTDIR)$(INITDIR_SYSTEMD_SYSTEM)/asd-resync.service"
	$(RM) "$(DESTDIR)$(INITDIR_SYSTEMD_SYSTEM)/asd-resync.timer"
	$(RM) "$(DESTDIR)$(INITDIR_SYSTEMD_USER)/asd.service"
	$(RM) "$(DESTDIR)$(INITDIR_SYSTEMD_USER)/asd-resync.service"
	$(RM) "$(DESTDIR)$(INITDIR_SYSTEMD_USER)/asd-resync.timer"

uninstall-upstart:
	$(RM) "$(DESTDIR)$(CONFDIR)/asd.conf"
	$(RM) "$(DESTDIR)$(INITDIR_UPSTART)/asd"

uninstall-systemd-all: uninstall-bin uninstall-man uninstall-systemd

uninstall-upstart-all: uninstall-bin uninstall-man uninstall-cron uninstall-upstart

uninstall:
	$(Q)echo "run one of the following:"
	$(Q)echo "  make uninstall-systemd-all (systemd based systems)"
	$(Q)echo "  make uninstall-upstart-all (upstart based systems)"
	$(Q)echo
	$(Q)echo "or check out the Makefile for specific rules"

clean:
	$(RM) -f common/$(PN)

.PHONY: help install-bin install-man install-cron install-systemd install-upstart install-systemd-all install-upstart-all install uninstall-bin uninstall-man uninstall-cron uninstall-systemd uninstall-upstart uninstall-systemd-all uninstall clean
