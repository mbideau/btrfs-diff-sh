# Makefile for btrfs-diff
#
# Respect GNU make conventions
#  @see: https://www.gnu.org/software/make/manual/make.html#Makefile-Basics
#
# Copyright (C) 2019 Michael Bideau [France]
#
# This file is part of btrfs-diff.
#
# btrfs-diff is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# btrfs-diff is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with btrfs-diff.  If not, see <https://www.gnu.org/licenses/>.
#

# use POSIX standard shell and fail at first error
.POSIX:

# source
srcdir             ?= .

# program
MAIN_SCRIPT        := $(srcdir)/btrfs_diff.sh
PROGRAM_NAME       ?= $(subst _,-,$(basename $(notdir $(MAIN_SCRIPT))))

# package infos
PACKAGE_NAME       ?= $(PROGRAM_NAME)
PACKAGE_VERS       ?= 0.1.0

# author
AUTHOR_NAME        := Michael Bideau
EMAIL_SUPPORT      := mica.devel@gmail.com

# charset and languages
CHARSET            := UTF-8
LOCALES            := fr
LOCALES_PLUS_EN    := en $(LOCALES)

# temp dir
TMPDIR             ?= $(srcdir)/.tmp

# destination
# @see: https://www.gnu.org/software/make/manual/make.html#Directory-Variables
prefix             ?= /usr/local
exec_prefix        ?= $(prefix)
bindir             ?= $(exec_prefix)/bin
sbindir            ?= $(exec_prefix)/sbin
ifeq ($(strip $(prefix)),)
datarootdir        ?= $(prefix)/usr/share
else
datarootdir        ?= $(prefix)/share
endif
datadir            ?= $(datarootdir)
ifeq ($(strip $(prefix)),/usr)
sysconfdir         ?= /etc
else
sysconfdir         ?= $(prefix)/etc
endif
infodir            ?= $(datarootdir)/info
libdir             ?= $(exec_prefix)/lib
localedir          ?= $(datarootdir)/locale
mandir             ?= $(datarootdir)/man
dirs_var_name      := prefix exec_prefix bindir sbindir datarootdir datadir sysconfdir infodir libdir localedir mandir

# install
INSTALL            ?= install
INSTALL_PROGRAM    ?= $(INSTALL) $(INSTALLFLAGS) --mode 755
INSTALL_DATA       ?= $(INSTALL) $(INSTALLFLAGS) --mode 644
INSTALL_DIRECTORY  ?= $(INSTALL) $(INSTALLFLAGS) --directory --mode 755

# locale specific
MAIL_BUGS_TO       := $(EMAIL_SUPPORT)
TEXTDOMAIN         := $(PACKAGE_NAME)
LOCALE_DIR         := $(srcdir)/locale
PO_FILES            = $(LOCALES:%=$(LOCALE_DIR)/%/LC_MESSAGES/$(TEXTDOMAIN).po)
MO_FILES            = $(LOCALES:%=$(LOCALE_DIR)/%/LC_MESSAGES/$(TEXTDOMAIN).mo)
POT_FILE           := $(LOCALE_DIR)/$(TEXTDOMAIN).pot

# man specific
MAN_DIR            := $(TMPDIR)/man
MAN_SECTION        ?= 1
MAN_FILENAME       := $(PACKAGE_NAME)

# generated files/dirs
LOCALE_DIRS         = $(LOCALES:%=$(LOCALE_DIR)/%/LC_MESSAGES)
MANS                = $(LOCALES_PLUS_EN:%=$(MAN_DIR)/%.texi.gz)
DIRS                = $(LOCALE_DIR) $(LOCALE_DIRS) $(TMPDIR) $(MAN_DIR)

# destinations files/dirs
INST_MAIN_SCRIPT   ?= $(DESTDIR)$(bindir)/$(PROGRAM_NAME)
INST_LOCALES        = $(LOCALES:%=$(DESTDIR)$(localedir)/%/LC_MESSAGES/$(TEXTDOMAIN).mo)
INST_MANS           = $(LOCALES_PLUS_EN:%=$(DESTDIR)$(mandir)/%/man$(MAN_SECTION)/$(PACKAGE_NAME).$(MAN_SECTION).gz)
INST_FILES          = $(INST_MAIN_SCRIPT) $(INST_LOCALES) $(INST_MANS)
INST_DIRS           = $(dir $(INST_MAIN_SCRIPT)) $(dir $(INST_LOCALES)) $(dir $(INST_MANS))

# distribution
DIST_DIR           := $(TMPDIR)/dist
DIST_DIRNAME       ?= $(PACKAGE_NAME)-$(PACKAGE_VERS)
DIST_DIRPATH       := $(DIST_DIR)/$(DIST_DIRNAME)
DIST_SRC_FILES      = $(MAIN_SCRIPT) $(PO_FILES) $(srcdir)/README.md $(srcdir)/LICENSE.txt $(srcdir)/Makefile
DIST_FILES          = $(subst $(srcdir)/,$(DIST_DIRPATH)/,$(DIST_SRC_FILES))
DIST_DIRS           = $(sort $(dir $(DIST_FILES)))
DIST_TARNAME       ?= $(DIST_DIRNAME).tar.gz
DIST_TARPATH       := $(DIST_DIR)/$(DIST_TARNAME)
DIST_TARFLAGS      := --create --auto-compress --posix --mode=0755 --recursion --exclude-vcs \
                      --file "$(DIST_TARPATH)"  \
                      --directory "$(DIST_DIR)" \
                      "$(DIST_DIRNAME)"

# tests
TEST_SCRIPT        := $(srcdir)/test.sh

# Debian packaging
DEBEMAIL           ?= $(EMAIL_SUPPORT)
DEBFULLNAME        ?= $(AUTHOR_NAME)
DEB_DIR            := $(TMPDIR)/deb
DEB_NAME           ?= $(PACKAGE_NAME)-$(PACKAGE_VERS)
DEB_FILENAME       := $(PACKAGE_NAME)-$(PACKAGE_VERS).deb
DEB_DIRPATH        := $(DEB_DIR)/$(DEB_FILENAME)
DEB_DATA           := $(DEB_DIR)/$(DEB_FILENAME)/data

# msginit and msgmerge use the WIDTH to break lines
WIDTH              ?= 80

# which shell to use
SHELL              := /bin/sh

# binaries
GETTEXT            ?= gettext
XGETTEXT           ?= xgettext
MSGFMT             ?= msgfmt
MSGINIT            ?= msginit
MSGMERGE           ?= msgmerge
MSGCAT             ?= msgcat
GZIP               ?= gzip
TAR                ?= tar
SHELLCHECK         ?= shellcheck
GIMME_A_MAN        ?= gimme-a-man
SHUNIT2            ?= $(TMPDIR)/shunit2

# binaries flags
GETTEXTFLAGS       ?=
GETTEXTFLAGS_ALL   := -d "$(TEXTDOMAIN)"
XGETTEXTFLAGS      ?=
XGETTEXTFLAGS_ALL  := --keyword --keyword=__ \
				      --language=shell --from-code=$(CHARSET) \
				      --width=$(WIDTH)       \
				      --sort-output          \
				      --foreign-user         \
				      --package-name="$(PACKAGE_NAME)" --package-version="$(PACKAGE_VERS)" \
				      --msgid-bugs-address="$(MAIL_BUGS_TO)"
MSGFMTFLAGS        ?=
MSGFMTFLAGS_ALL    := --check --check-compatibility
MSGINITFLAGS       ?=
MSGINITFLAGS_ALL   := --no-translator  --width=$(WIDTH)
MSGMERGEFLAGS      ?=
MSGMERGEFLAGS_ALL  := --quiet
MGSCATFLAGS        ?=
MGSCATFLAGS_ALL    := --sort-output --width=$(WIDTH)
GZIPFLAGS          ?=
TARFLAGS           ?= --gzip
SHELLCHECKFLAGS    ?=
SHELLCHECKFLAGS_ALL:= --check-sourced --external-sources

# man helper flags
GIMME_A_MAN_FLAGS     ?=
GIMME_A_MAN_ARGS_ALL  := $(MAIN_SCRIPT) $(PACKAGE_NAME) "$(PACKAGE_NAME) $(PACKAGE_VERS)" $(MAN_SECTION)


# Use theses suffixes in rules
.SUFFIXES: .po .mo .pot .gz .sh

# Do not delete those files even if they are intermediaries to other targets
.PRECIOUS: $(LOCALE_DIR)/%/LC_MESSAGES/$(TEXTDOMAIN).mo


# replace a variable inside a file (inplace) if not empty (except for PREFIX)
# $(1) string  the name of the variable to replace (will be uppercased)
# $(2) string  the value of the variable to set
# $(3) string  the path to the file to modify
define replace_var_in_file
	name_upper="`echo "$(1)"|tr '[:lower:]' '[:upper:]'`"; \
	if grep -q "^[[:space:]]*$$name_upper=" "$(3)"; then \
		if [ "$(2)" != '' -o "$$name_upper" = 'PREFIX' ]; then \
			echo "## Replacing var '$$name_upper' with value '$(2)' in file '$(3)'"; \
			sed -e "s#^\([[:blank:]]*$$name_upper=\).*#\1"'"'"$(2)"'"'"#g" -i "$(3)"; \
		fi; \
	fi;
endef

# create man page from help of the main script with translation support
# $(1) string the locale
# $(2) string the path to man file output
define generate_man_from_mainscript_help
	@_locale_short="$(1)"; \
	_locale="$$_locale_short"; \
	if [ "$$(printf '%%s' "$$_locale_short" | wc -c)" -eq 2 ]; then \
		_locale="$${_locale_short}_$$(echo "$$_locale_short" | tr '[a-z]' '[A-Z]').$(CHARSET)"; \
	fi; \
	if [ ! -e "$(2)" ]; then \
		echo "## Creating man page '$(2)' [$$_locale_short]"; \
	else \
		echo "## Updating man page '$(2)' [$$_locale_short]"; \
	fi; \
	if ! $(GIMME_A_MAN)                                    \
		--locale "$$_locale"                          \
		$(GIMME_A_MAN_FLAGS) $(GIMME_A_MAN_FLAGS_ALL) \
		$(GIMME_A_MAN_ARGS_ALL)                       \
	| $(GZIP) $(GZIPFLAGS) > "$(2)"; then exit 1; fi;
endef


# special case for english manual that do not depends on any translation but on main script
$(MAN_DIR)/en.texi.gz: $(MAIN_SCRIPT)
	@$(call generate_man_from_mainscript_help,en,$@)


# manuals depends on translations
$(MAN_DIR)/%.texi.gz: $(LOCALE_DIR)/%/LC_MESSAGES/$(TEXTDOMAIN).mo $(MAIN_SCRIPT)
	@$(call generate_man_from_mainscript_help,$*,$@)


# compiled translations depends on their not-compiled sources
$(LOCALE_DIR)/%/LC_MESSAGES/$(TEXTDOMAIN).mo: $(LOCALE_DIR)/%/LC_MESSAGES/$(TEXTDOMAIN).po
	@echo "## Compiling catalogue '$<' to '$@'"
	@$(MSGFMT) $(MSGFMTFLAGS) $(MSGFMTFLAGS_ALL) --output "$@" "$<"


# translations files depends on the main translation catalogue
$(LOCALE_DIR)/%/LC_MESSAGES/$(TEXTDOMAIN).po: $(POT_FILE)
	@_locale_short="$$(dirname "$$(dirname "$@")")"; \
	_locale="$$_locale_short"; \
	if [ "$$(printf '%%s' "$$_locale_short" | wc -c)" -eq 2 ]; then \
		_locale="$${_locale_short}_$$(echo "$$_locale_short" | tr '[a-z]' '[A-Z]').$(CHARSET)"; \
	fi; \
	if [ ! -e "$@" ]; then \
		echo "## Initializing catalogue '$@' from '$<' [$$_locale_short]"; \
		$(MSGINIT) $(MSGINITFLAGS) $(MSGINITFLAGS_ALL) --input "$<" --output "$@" \
			--locale="$$_locale" >/dev/null; \
	else \
		echo "## Updating catalogue '$@' from '$(POT_FILE)' [$$_locale_short]"; \
		$(MSGMERGE) $(MSGMERGEFLAGS) $(MSGMERGEFLAGS_ALL) --update "$@" "$<"; \
		touch "$@"; \
	fi;


# main translation catalogue depends on main script
$(POT_FILE): $(MAIN_SCRIPT)
	@echo "## (re-)generating '$@' from '$<' ..."
	@$(XGETTEXT) $(XGETTEXTFLAGS) $(XGETTEXTFLAGS_ALL) --output "$@" "$<"


# create all required directories
$(DIRS):
	@echo "## Creating directory '$@'"
	@mkdir -p "$@"


# create all install directories
$(INST_DIRS):
	$(PRE_INSTALL)
	@echo "## Creating directory '$@'"
	@mkdir -p -m 0750 "$@"


# install main script
$(INST_MAIN_SCRIPT): $(MAIN_SCRIPT)
	@echo "## Installing main script '$(notdir $<)' to '$@'"
	@$(INSTALL_PROGRAM) "$<" "$@"
	@$(call replace_var_in_file,PACKAGE_NAME,$(PACKAGE_NAME),$@)
	@$(call replace_var_in_file,VERSION,$(PACKAGE_VERS),$@)
	@$(foreach name,$(dirs_var_name),$(call replace_var_in_file,$(name),$($(name)),$@))


# install locales
$(DESTDIR)$(localedir)/%/LC_MESSAGES/$(TEXTDOMAIN).mo: $(LOCALE_DIR)/%/LC_MESSAGES/$(TEXTDOMAIN).mo
	@echo "## Installing locale '$*' to '$@'"
	@$(INSTALL_DATA) "$<" "$@"


# install man files
$(DESTDIR)$(mandir)/%/man$(MAN_SECTION)/$(PACKAGE_NAME).$(MAN_SECTION).gz: $(MAN_DIR)/%.texi.gz
	@echo "## Installing man '$*' to '$@'"
	@$(INSTALL_DATA) "$<" "$@"



# to build everything, create directories then 
# all the man files (they depends on all the rest)
all: $(DIRS) $(MANS)


# install all files to their proper location
install: all $(INST_DIRS) $(INST_FILES)


# uninstall
uninstall:
	@echo "## Removing files ..."
	@echo "$(INST_FILES)" | tr ' ' '\n' | sed 's/^/##   /g'
	@$(RM) $(INST_FILES)
	@echo "## Removing directories (only the empty ones will be actually removed) ..."
	@echo "$(INST_DIRS)" | tr ' ' '\n' | sed 's/^/##   /g'
	-@rmdir --parents $(INST_DIRS) 2>/dev/null||true


# cleanup
clean:
	@echo "## Removing files ..."
	@echo "$(LOCALE_DIR)/*/LC_MESSAGES/*~ $(srcdir)/*~"
	@$(RM) $(LOCALE_DIR)/*/LC_MESSAGES/*~ $(srcdir)/*~
	@echo "## Removing directory ..."
	@echo "$(TMPDIR)"
	@$(RM) -r $(TMPDIR)


# test
test: $(TMPDIR)
	@[ -e "$(SHUNIT2)" ] || { echo "shunit2 ($(SHUNIT2)) not found" && exit 3; }
	@echo "## Running test ..."
	@TMPDIR="$(TMPDIR)" SHUNIT2="$(SHUNIT2)" $(SHELL) $(TEST_SCRIPT)


# shellcheck
shellcheck:
	@echo "## Checking shell errors and POSIX compatibility"
	@for s in $(MAIN_SCRIPT) $(TEST_SCRIPT); do \
	    echo "  $$s"; \
	    _extra_args=''; \
	    $(SHELLCHECK) $(SHELLCHECKFLAGS) $(SHELLCHECKFLAGS_ALL) $$_extra_args "$$s"; \
	done;


# create all dist directories
$(DIST_DIRS):
	@echo "## Creating directory '$@'"
	@mkdir -p -m 0755 "$@"


# copy (hard link) source files
$(DIST_DIRPATH)/%: $(srcdir)/%
	@echo "## Copying source file '$<' to '$@'"
	@ln "$<" "$@"


# distribution tarball
$(DIST_TARPATH): $(DIST_FILES)
	@echo "## Creating distribution tarball '$@'"
	@$(TAR) $(TARFLAGS) $(DIST_TARFLAGS)


# create a distribution tarball
dist: all $(DIST_DIRS) $(DIST_TARPATH)


# dist cleanup
distclean: clean


# catch-all
.PHONY: all install uninstall clean test shellcheck dist distclean


# default target
.DEFAULT_GOAL := all

# vim:set ts=4 sw=4
