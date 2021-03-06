#!/bin/sh
#
# Testing for 'btrfs-diff' utility.
#
# Standards in this script:
#   POSIX compliance:
#      - http://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
#      - https://www.gnu.org/software/autoconf/manual/autoconf.html#Portable-Shell
#   CLI standards:
#      - https://www.gnu.org/prep/standards/standards.html#Command_002dLine-Interfaces
#
# Source code, documentation and support:
#   https://github.com/mbideau/btrfs-diff
#
# Copyright (C) 2020 Michael Bideau [France]
#
# This file is part of btrfs-diff-sh.
#
# btrfs-diff-sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# btrfs-diff-sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with btrfs-diff-sh. If not, see <https://www.gnu.org/licenses/>.
#

# TODO find a way to generate 'truncate' and 'clone' BTRFS instructions


# halt on first error
set -e

# 'btrfs-diff' root directory
THIS_DIR="$(dirname "$(realpath "$0")")"

if [ "$BTRFS_DIFF" = '' ]; then
    if ! BTRFS_DIFF="$(which btrfs-diff 2>/dev/null)"; then
        if [ -x "$THIS_DIR/btrfs_diff.sh" ]; then
            BTRFS_DIFF="$THIS_DIR/btrfs_diff.sh"
        else
            echo "Fatal error: failed to find binary 'btrfs-diff'" >&2
            exit 1
        fi
    fi
fi

if [ "$SHUNIT2" = '' ]; then
    if ! SHUNIT2="$(which shunit2)"; then
        if [ -r "$(dirname "$THIS_DIR")/shunit2/shunit2" ]; then
            SHUNIT2="$(dirname "$THIS_DIR")/shunit2/shunit2"
        else
            echo "Fatal error: failed to find shell script 'shunit2'" >&2
            exit 1
        fi
    fi
fi

# configuration of the test environment
TEST_DIR="$THIS_DIR"/tests
DATA_DIR="$TEST_DIR"/data
SNAPS_DIR="$TEST_DIR"/snaps


# helper functions

__debug()
{
    if [ "$DEBUG_TEST" = 'true' ]; then
        # shellcheck disable=SC2059
        printf "$@" | sed 's/^/[TEST DEBUG] /g' >&2
    fi
}

escape_eval()
{
    echo "$1" | sed -e 's/\\/\\\\/g' -e 's/\([]$*^?&`|("'"'"')[]\)/\\\1/g'
}

# shunit2 functions

__warn()
{
    # shellcheck disable=SC2154
    ${__SHUNIT_CMD_ECHO_ESC} "${__shunit_ansi_yellow}WARN${__shunit_ansi_none} $*" >&2
}

# initial setup
oneTimeSetUp()
{
    # create the test directory
    if [ ! -d "$TEST_DIR" ]; then
        __debug "Creating directory: '%s'\n" "$TEST_DIR"
        mkdir "$TEST_DIR"
    fi

    # remove exiting files
    tearDown
}


# final tear down / cleanup
oneTimeTearDown()
{
    # remove the tests dir
    if [ -d "$TEST_DIR" ]; then
        __debug "Removing directory: '%s'\n" "$TEST_DIR"
        rmdir "$TEST_DIR"
    fi
}

# reset conf data and savepoints
setUp()
{
    __debug "Creating a subvolume that will contains the data: '%s' (read-write)\n" "$DATA_DIR"
    btrfs subvolume create "$DATA_DIR" > /dev/null

    __debug "Creating a directory that will contains the snapshots: '%s'\n" "$SNAPS_DIR"
    [ ! -d "$SNAPS_DIR" ] && mkdir -p "$SNAPS_DIR"

    __debug "Creating first snapshot (with no data) '%s'\n" "$SNAPS_DIR"/000
    btrfs subvolume snapshot -r "$DATA_DIR" "$SNAPS_DIR"/000 > /dev/null
}

tearDown()
{
    __debug "Removing existing data and snapshots\n"
    [ ! -d "$DATA_DIR" ] || btrfs subvolume delete "$DATA_DIR" > /dev/null
    if [ -d "$SNAPS_DIR" ]; then
        if [ "$(ls "$SNAPS_DIR")" != '' ]; then
            for snap in "$SNAPS_DIR"/*; do
                btrfs subvolume delete "$snap" > /dev/null
            done
        fi
        rmdir "$SNAPS_DIR"
    fi
}


# tests cases

# inspired by: 'btrfs-send-go' tests cases
test__lotsOfOperationsAndDiffAnalysis()
{
    __debug "Creating data and snapshots for each commands\n"
    I=1
    { cat <<ENDCAT
    echo foo > foo_file
    mkdir bar
    mv foo_file bar
    echo baz > bar/baz_file
    ln bar/baz_file bar/baaz_file
    mv bar/baz_file bar/foo_file
    rm bar/foo_file
    echo super_ugly_filename > cec]i[est-une\`hor#rible|ch.enne&de@charactère}q{ui~\$'assume)d(epuis*longtemps\sinon+voir^encore?.txt
    rm -rf bar
    mkdir dir
    touch dir/file
    mkfifo dir/fifo
    ln dir/file dir/hardlink
    ln -s file dir/symlink
    mv dir/hardlink dir/hardlink.rn
    mv dir/symlink dir/symlink.rn
    mv dir/fifo dir/fifo.rn
    echo todel > dir/file_to_del
    rm -rf dir
ENDCAT
} | grep -v '^\s*#' | while read -r command; do
        __debug '%d: %s\n' "$I" "$command"
        cd "$DATA_DIR"
        eval "$(escape_eval "$command")"
        cd - >/dev/null
        btrfs subvolume snapshot -r "$DATA_DIR" "$SNAPS_DIR/$(printf "%03i" $I)" > /dev/null
        I="$((I + 1))"
    done

    __debug "Comparing snapshots between them with '%s' "`
            `"then with '%s' and printing unmatching lines (between both diffs)\n" \
            "$BTRFS_DIFF" 'diff'

    # looping twice on snapshots
    for A in "$SNAPS_DIR"/*; do
        for B in "$SNAPS_DIR"/*; do

            # do not compare identical snapshots
            [ "$A" != "$B" ] || continue

            [ "$DEBUG_TEST" = 'true' ] || printf '.'

            __debug "Comparing snapshots '%s' and '%s'\n" \
                "$(echo "$A" | sed "s|$TEST_DIR/\?||g")" \
                "$(echo "$B" | sed "s|$TEST_DIR/\?||g")"

            # produce a diff using the 'btrfs-diff' binary
            LC_ALL=C "$BTRFS_DIFF" -d "$A" "$B" >/tmp/out.diff 2>&1 || true
            __debug "Result:\n---\n%s\n---\n" "$(cat /tmp/out.diff)"

            # diff the diffs between them and report differences
            assertContains "$(cat /tmp/out.diff)" \
                "Note: same output as with the standard 'diff' utility"
        done
        [ "$DEBUG_TEST" = 'true' ] || echo
    done
}

# run shunit2
# shellcheck disable=SC1090
. "$SHUNIT2"
