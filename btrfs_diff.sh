#!/bin/sh
#
# get differences between two BTRFS snapshots.
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

# TODO use less buffer files

# TODO understand why BTRFS report that some files have changed when they have not ?!


# halt on first error
set -e


# package infos
VERSION=0.1.0
PACKAGE_NAME=btrfs-diff
AUTHOR='Michael Bideau'
HOME_PAGE='https://github.com/mbideau/btrfs-diff-sh'
REPORT_BUGS_TO="$HOME_PAGE/issues"
PROGRAM_NAME="$PACKAGE_NAME"


# technical vars
THIS_SCRIPT_PATH="$(realpath "$0")"
THIS_SCRIPT_NAME="$(basename "$THIS_SCRIPT_PATH")"
THIS_SCRIPT_DIR="$(dirname "$THIS_SCRIPT_PATH")"


# functions

# sets all required locale variables and exports
setup_language()
{
    # translation variables

    # gettext binary or echo
    GETTEXT="$(which gettext 2>/dev/null || which echo)"

    # gettext domain name
    TEXTDOMAIN="$PACKAGE_NAME"

    # gettext domain directory
    if [ "$TEXTDOMAINDIR" = '' ]; then
        if [ -d "$THIS_SCRIPT_DIR"/locale ]; then
            TEXTDOMAINDIR="$THIS_SCRIPT_DIR"/locale
        elif [ -d /usr/share/locale ]; then
            TEXTDOMAINDIR=/usr/share/locale
        fi
    fi

    # environment variable priority defined by gettext are : LANGUAGE, LC_ALL, LC_xx, LANG
    # see: https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html#Locale-Environment-Variables
    # and: https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html#The-LANGUAGE-variable

    # gettext requires that at least one local is specified and different from 'C' in order to work
    if { [ "$LC_ALL" = '' ] || [ "$LC_ALL" = 'C' ]; } && { [ "$LANG" = '' ] || [ "$LANG" = 'C' ]; }
    then

        # set the LANG to C.UTF-8 so gettext can handle the LANGUAGE specified
        LANG=C.UTF-8
    fi

    # export language settings
    export TEXTDOMAIN
    export TEXTDOMAINDIR
    export LANGUAGE
    export LC_ALL
    export LANG
}

# translate a text and use printf to replace strings
# @param  $1  string  the string to translate
# @param  ..  string  string to substitute to '%s' (see printf format)
__()
{
    _t="$("$GETTEXT" "$1" | tr -d '\n')"
    shift
    # shellcheck disable=SC2059
    printf "$_t\\n" "$@"
}

# print out debug information to STDERR
# @param  $1  formatting (like first arg of printf)
# @param  ..  string  string to substitute to '%s' (see printf format)
debug()
{
    if [ "$DEBUG" = "$PROGRAM_NAME" ]; then
        # shellcheck disable=SC2059
        printf "$@" | sed 's/^/[DEBUG] /g' >&2
    fi
}

# return 0 if the path is a subvolume
# @from: https://stackoverflow.com/a/25908150
is_btrfs_subvolume()
{
    case "$(stat -f -c "%T" "$1")" in
       btrfs|UNKNOWN) ;;
       *) return 1 ;;
    esac
    case "$(stat -c "%i" "$1")" in
        2|256) return 0 ;;
        *) return 1 ;;
    esac
}

# escape a 'grep' or a 'sed' pattern
# @param  $1  string  the pattern to escape
escape_pattern()
{
    # shellcheck disable=SC1003
    echo "$1" | sed 's/\([].$*^\\[]\)/\\\1/g'
}

# get the path relative to the compared snapshot directory
# @param  $1        string   the absolute path of the snapshot
# @env    $cmp_dir  string   the path to the compared snapshot directory
rel_path()
{
    echo "$1" | sed "s|^\./$(escape_pattern "$cmp_dir" | sed 's/|/\\|/g')||"
}

# return 0 is the specified name match format: '^o[0-9]\+-[0-9]\+-[0-9]\+$'
# @param  $1  string  the name of the file/directory to check for
is_temp_object()
{
    echo "$1" | grep -q '^o[0-9]\+-[0-9]\+-[0-9]\+$'
}

# usage
usage()
{
    cat <<ENDCAT

$PROGRAM_NAME - $( __ 'get differences between two BTRFS snapshots.')

$(__ 'USAGE')

    $PROGRAM_NAME $(__ 'SNAP_REF') $(__ 'SNAP_CMP') [ -t | --with-times ] [ -p | --with-props ]
    $PROGRAM_NAME -f|--file $(__ 'DUMP_FILE') [ -t | --with-times ] [ -p | --with-props ]

    $PROGRAM_NAME [ -h | --help ]
    $PROGRAM_NAME [ -v | --version ]


$(__ 'ARGUMENTS')

    $(__ 'SNAP_REF')
        $(__ 'Path to the reference snapshot.')
        $(__ 'It must be a read-only one.')

    $(__ 'SNAP_CMP')
        $(__ 'Path to the compared snapshot.')
        $(__ 'It must also be a read-only one.')

    $(__ 'DUMP_FILE')
        $(__ "A file containing the output of the command '%s'." \
            'LC_ALL=C btrfs receive --quiet --dump')


$(__ 'OPTIONS')

    -d | --compare-to-std-diff
        $(__ "Compare the result against the output of the standard '%s' utility." \
          'diff')
        $(__ "This option is ignored when the option '%s' is also specified." '--file')

    -f | --file
        $(__ "Instead of two snapshots, use a file containing the %s output of the snapshots." 'send/receive')

    -t | --with-times
        $(__ 'Report times differences %s' '(atime, mtime, ctime)')

    -p | --with-props
        $(__ 'Report properties differences %s' '(chmod, chown, set_xattr)')

    -h | --help
        $(__ 'Display help message.')

    -v | --version
        $(__ 'Display version and license informations.')


$(__ 'EXAMPLES')

    $(__ 'Get the differences between two snapshots.')
    \$ $PROGRAM_NAME /backup/btrfs-sp/rootfs/2020-12-25_22h00m00.shutdown.safe \\
        /backup/btrfs-sp/rootfs/2019-12-25_21h00m00.shutdown.safe


    $(__ 'Create the dump of the send/receive between two snapshots.')
    \$ btrfs send --quiet --no-data -p /backup/btrfs-sp/rootfs/2020-12-25_22h00m00.shutdown.safe \\
        /backup/btrfs-sp/rootfs/2019-12-25_21h00m00.shutdown.safe \\
        | LC_ALL=C btrfs receive --quiet --dump > /tmp/btrfs.dump

    $(__ 'Get the differences between two snapshots.')
    \$ $PROGRAM_NAME --file /tmp/btrfs.dump


$(__ 'ENVIRONMENT')

    DEBUG
        $(__ "Print debugging information to '%s' only if var %s='%s'." 'STDERR' 'DEBUG' "$PROGRAM_NAME")

    LANGUAGE
    LC_ALL
    LANG
    TEXTDOMAINDIR
        $(__ "Influence the translation.")
        $(__ "See %s documentation." 'GNU gettext')


$(__ 'AUTHORS')

    $(__ 'Written by'): $AUTHOR


$(__ 'REPORTING BUGS')

    $(__ 'Report bugs to'): <$REPORT_BUGS_TO>


$(__ 'COPYRIGHT')

    $(usage_version | tail -n +2 | sed "2,$ s/^/    /")


$(__ 'SEE ALSO')

    $(__ 'Home page'): <$HOME_PAGE>

ENDCAT
}

# display version
usage_version()
{
    _year="$(date '+%Y')"
    cat <<ENDCAT
$PROGRAM_NAME $VERSION
Copyright C 2020$([ "$_year" = '2020' ] || echo "-$_year") $AUTHOR.
$(__ "License %s: %s <%s>" 'GPLv3+' 'GNU GPL version 3 or later' 'https://gnu.org/licenses/gpl.html')
$(__ "This is free software: you are free to change and redistribute it.")
$(__ "There is NO WARRANTY, to the extent permitted by law.")
ENDCAT
}


# main program

# options (requires GNU getopt)
if ! TEMP="$(getopt -o 'df:tphv' \
                    --long 'compare-to-std-diff,file:,with-times,with-props,help,version' \
                    -n "$THIS_SCRIPT_NAME" -- "$@")"
then
    __ 'Fatal error: invalid option' >&2
    exit 1
fi
eval set -- "$TEMP"

opt_file=false
opt_with_times=false
opt_with_props=false
opt_help=false
opt_version=false
opt_compare_to_std_diff=false
while true; do
    # shellcheck disable=SC2034
    case "$1" in
        -d | --compare-to-std-diff) opt_compare_to_std_diff=true ; shift ;;
        -f | --file               ) opt_file=true                ; shift ;;
        -t | --with-times         ) opt_with_times=true          ; shift ;;
        -p | --with-props         ) opt_with_props=true          ; shift ;;
        -h | --help               ) opt_help=true                ; shift ;;
        -v | --version            ) opt_version=true             ; shift ;;
        -- ) shift; break ;;
        *  ) break ;;
    esac
done

# setup language
setup_language

# help/usage
if [ "$opt_help" = 'true' ]; then
    usage
    exit 0
fi

# display version
if [ "$opt_version" = 'true' ]; then
    usage_version
    exit 0
fi


# main program

# setup a trap to remove all the temporary files
# shellcheck disable=SC2064
trap "[ ! -d '$_tmp_dir' ] || rm -fr '$_tmp_dir'" INT QUIT ABRT TERM EXIT

# create a temporary directory to contain all the temporary files
_tmp_dir="$(mktemp -d)"


# not using --file option
if [ "$opt_file" != 'true' ]; then

    # snapshot paths
    _snap_ref="$1"
    _snap_cmp="$2"

    # should be different
    [ "$_snap_ref" != "$_snap_cmp" ] || exit 0

    _raw_diff="$_tmp_dir"/raw_diff.txt

    # ensure arguments are BTRFS subvolumes
    if ! is_btrfs_subvolume "$_snap_ref"; then
        __ "Fatal error: '%s' is not a btrfs subvolume" "$_snap_ref" && exit 3
    fi
    if ! is_btrfs_subvolume "$_snap_cmp"; then
        __ "Fatal error: '%s' is not a btrfs subvolume" "$_snap_cmp" && exit 3
    fi

    # get a raw diff with the BTRFS tools
    if ! btrfs send --quiet --no-data -p "$_snap_ref" "$_snap_cmp" \
        | LC_ALL=C btrfs receive --quiet --dump \
        >"$_raw_diff"
    then
        __ "Fatal error: failed to get a raw diff with send/received for snapshots '%s' and '%s'" \
            "$_snap_ref" "$_snap_cmp" && exit 3
    fi


# using --file option
else
    _raw_diff="$1"

    if [ ! -r "$_raw_diff" ]; then
        __ "Fatal error: the file '%s' doesn't exist or is not readable" "$_raw_diff" && exit 3
    fi
fi


# operations
op_added="$(  __ '  added')"
op_deleted="$(__ 'deleted')"
op_changed="$(__ 'changed')"
op_renamed="$(__ 'renamed')"
op_props="$(  __ '  props')"
op_times="$(  __ '  times')"

# use temporary files as buffers (can handle larger output than SHELL variables)
_out="$_tmp_dir"/out.txt
_newdirs_buffer="$_tmp_dir"/newdirs_buffer.txt
_newfiles_buffer="$_tmp_dir"/newfiles_buffer.txt
_extfiles_buffer="$_tmp_dir"/extfiles_buffer.txt
_deldirs_buffer="$_tmp_dir"/deldirs_buffer.txt
_delfiles_buffer="$_tmp_dir"/delfiles_buffer.txt
_objects_buffer="$_tmp_dir"/objects_buffer.txt
touch  "$_out" "$_newdirs_buffer" "$_newfiles_buffer" "$_deldirs_buffer" "$_delfiles_buffer" \
       "$_objects_buffer"


# read each line of the raw diff and try to produce a more realistic view (like standard 'diff')
cmp_dir=
rel_path=
while read -r line; do

    debug '<<< %s\n' "$line"
    _ind='   '
    op="$(echo "$line" | awk '{print $1}')"
    path="$(echo "$line" | awk '{$1=""; print $0}' | grep -o '^ *\([^ ]\+\|\\ \)\+' \
            |sed -e 's/\\ / /g' -e 's/^ *//g')"
    fn="$(basename "$path")"
    parent="$(dirname "$path")"
    [ "$cmp_dir" = '' ] || rel_path="$(rel_path "$path")"

    debug "${_ind}path: '%s'\n" "$path"

    if grep -q "^$(escape_pattern "$parent")\$" "$_newdirs_buffer"; then
        debug "${_ind}ignoring (inside new dir '%s')\n" "$parent"
        continue
    fi

    # depending on the operation
    case "$op" in
        mkfile|mkfifo|mkdir)
            _obj_line="$op|$path|$rel_path"
            debug "${_ind}adding to object buffer: '%s'\n" "$_obj_line"
            echo "$_obj_line" >> "$_objects_buffer"
            if [ "$op" = 'mkdir' ]; then
                debug "${_ind}adding '%s' to the newdirs buffer\n" "$path"
                echo "$path" >> "$_newdirs_buffer"
            else
                debug "${_ind}adding '%s' to the newfiles buffer\n" "$path"
                echo "$path" >> "$_newfiles_buffer"
            fi
            ;;

        link)
            debug ">>> %s: '%s'\n" "$op_added" "$rel_path"
            echo "$op_added: $rel_path" >> "$_out"
            ;;

        symlink)
            _dst="$(echo "$line" | sed -e 's/^.* \+dest=//' -e 's/^ *//g')"
            _dst_fn="$(basename "$_dst")"
            _dst_rel="$(rel_path "$_dst")"

            # from an object to a real thing
            if is_temp_object "$fn"; then
                debug "${_ind}symlink from an object '%s' to a real thing '%s'\n" \
                    "$path" "$_dst"
                _obj_line="$op|$path|$rel_path"
                debug "${_ind}adding to object buffer: '%s'\n" "$_obj_line"
                echo "$_obj_line" >> "$_objects_buffer"

            # from a real thing to an object
            elif is_temp_object "$_dst_fn"; then
                if ! grep -q "^[^|]\\+|$(escape_pattern "$_dst")|" "$_objects_buffer"; then
                    __ "Fatal error: when symlinking '%s' to '%s', the destination wasn't found in the objects buffer" \
                            "$path" "$_dst" >&2
                    exit 3
                fi
                debug "${_ind}symlink from a real thing '%s' to an object '%s'\n" \
                    "$path" "$_dst"

                _obj_line="$op|$path|$rel_path|$_dst|$_dst_rel"
                debug "${_ind}adding to object buffer: '%s'\n" "$_obj_line"
                echo "$_obj_line" >> "$_objects_buffer"

            # from a real thing to another real thing
            else
                debug "${_ind}symlink from a real thing '%s' to another real thing '%s'\n"
                    "$path" "$_dst"
                debug ">>> %s: '%s'\n" "$op_added" "$rel_path"
                echo "$op_added: $rel_path" >> "$_out"
                echo "$path" >> "$_newfiles_buffer"
                debug "${_ind}adding '%s' to the newfiles buffer\n" "$path"
            fi
            ;;

        rename)
            _dst="$(echo "$line" | sed -e 's/^.* \+dest=//' -e 's/^ *//g')"
            _dst_fn="$(basename "$_dst")"
            _dst_rel="$(rel_path "$_dst")"

            # from object to real thing
            if is_temp_object "$fn"; then
                if ! _match="$(grep "^[^|]\\+|$(escape_pattern "$path")|" "$_objects_buffer")"; then
                    if ! _match="$(grep "^[^|]\\+|[^|]\+|[^|]\+|$(escape_pattern "$path")|" "$_objects_buffer")"; then
                        __ "Fatal error: when renaming '%s' to '%s', the source wasn't found in the objects buffer" \
                                "$path" "$_dst" >&2
                        exit 3
                    fi
                fi
                _op="$(echo "$_match" | awk -F '|' '{print $1}')"
                _type=
                case "$_op" in
                    mkfile|mkfifo|mkdir) _type="$(echo "$_op" | sed 's/^mk//')" ;;
                    link|symlink) _type="$_op" ;;
                    to_object) ;; # type unknown when its a renaming
                    *)
                        __ "Fatal error: when renaming '%s' to '%s', the operation '%s' found is invalid" \
                                "$path" "$_dst" "$_op" >&2
                        exit 3
                        ;;
                esac
                debug "${_ind}from object '%s' to real %s '%s'\n" "$path" "$_type" "$_dst"

                # in object dir
                _dst_dir="$(dirname "$_dst")"
                _dst_dir_fn="$(basename "$_dst_dir")"
                if is_temp_object "$_dst_dir_fn"; then
                    if ! grep -q "^[^|]\\+|$(escape_pattern "$_dst_dir")|" "$_objects_buffer"; then
                        __ "Fatal error: when renaming '%s' to '%s', the destination dir '%s' wasn't found "`
                            `"in the objects buffer" \
                                "$path" "$_dst" "$_dst_dir" >&2
                        exit 3
                    fi
                    debug "${_ind}in object dir '%s'\n" "$_dst_dir"
                    debug "${_ind}ignored\n"

                # in real dir
                else
                    debug "${_ind}in real dir '%s'\n" "$_dst_dir"

                    # in a new dir
                    if grep -q "^$(escape_pattern "$_dst_dir")\$" "$_newdirs_buffer"; then
                        debug "${_ind}in a new dir\n"
                        debug "${_ind}ignored\n"

                    # not a new dir
                    else

                        # if there is the same destination that was previously converted into an object
                        # it means this is a file that is being replaced by another one, i.e.: changed
                        if grep -q "^[^|]\\+|$(escape_pattern "$_dst")|" "$_objects_buffer"; then
                            debug "${_ind}destination '%s' found in object buffer\n" "$_dst"
                            debug "${_ind}which means this is a changed file (not and addition)\n"

                            debug ">>> %s: '%s'\n" "$op_changed" "$_dst_rel"
                            echo "$op_changed: $_dst_rel" >> "$_out"

                        # not a changed file
                        else

                            debug ">>> %s: '%s'\n" "$op_added" "$_dst_rel"
                            echo "$op_added: $_dst_rel" >> "$_out"
                        fi
                    fi

                    # update new things buffers
                    if [ "$_type" = 'dir' ]; then
                        debug "${_ind}adding '%s' to the newdirs buffer\n" "$_dst"
                        echo "$_dst" >> "$_newdirs_buffer"
                    else
                        debug "${_ind}adding '%s' to the newfiles buffer\n" "$_dst"
                        echo "$_dst" >> "$_newfiles_buffer"
                    fi
                fi

            # from real thing to object
            elif is_temp_object "$_dst_fn"; then
                debug "${_ind}from real thing '%s' to object '%s'\n" "$path" "$_dst"
                _obj_line="to_object|$path|$rel_path|$_dst|$_dst_rel"
                debug "${_ind}adding to object buffer: '%s'\n" "$_obj_line"
                echo "$_obj_line" >> "$_objects_buffer"
                debug "${_ind}ignored\n"

            # regular rename
            # Note: I think they doesn't exist, because they are made with link/unlink
            else
                debug "${_ind}regular rename from '%s' to '%s'\n" "$path" "$_dst"
                debug "${_ind}proof that, actually, real rename are a thing !\n"
                debug ">>> %s: '%s' to '%s'\n" "$op_renamed" "$rel_path" "$_dst_rel"
                echo "$op_renamed: $rel_path to $_dst_rel" >> "$_out"
            fi
            ;;

        update_extent)

            # extends an object
            if is_temp_object "$fn"; then
                debug "${_ind}extends an object\n"

                # rename should have happened before, hence the search on the path/source
                if ! grep -q "^[^|]\\+|$(escape_pattern "$path")|" "$_objects_buffer"; then
                    __ "Fatal error: when extending '%s', it wasn't found in the objects buffer" "$path" >&2
                    exit 3
                fi
                debug "${_ind}ignored\n"

            # extent on a new file or a changed file
            elif grep -q "^$(escape_pattern "$path")\$" "$_newfiles_buffer"; then
                debug "${_ind}extent on a new/changed file\n"
                debug "${_ind}ignored (created by the renaming)\n"

            # regular extent
            else
                debug "${_ind}adding '%s' to the extfiles buffer\n" "$_dst"
                echo "$path" >> "$_extfiles_buffer"
                debug ">>> %s: '%s'\n" "$op_changed" "$rel_path"
                echo "$op_changed: $rel_path" >> "$_out"
            fi
            ;;

        clone)

            # clones an object
            if is_temp_object "$fn"; then
                debug "${_ind}clones an object\n"

                # rename should have happened before, hence the search on the path/source
                if ! grep -q "^[^|]\\+|$(escape_pattern "$path")|" "$_objects_buffer"; then
                    __ "Fatal error: when cloning '%s', it wasn't found in the objects buffer" "$path" >&2
                    exit 3
                fi
                debug "${_ind}ignored\n"

            # cloning on a new file or a changed file
            elif grep -q "^$(escape_pattern "$path")\$" "$_newfiles_buffer"; then
                debug "${_ind}clone on a new/changed file\n"
                debug "${_ind}ignored (created by the renaming)\n"

            # regular cloning
            else
                debug ">>> %s: '%s'\n" "$op_changed" "$rel_path"
                echo "$op_changed: $rel_path" >> "$_out"
            fi
            ;;

        truncate)

            # truncate an object : do not exist ?
            if is_temp_object "$fn"; then
                debug "${_ind}truncate an object\n"

                # rename should have happened before, hence the search on the path/source
                if ! grep -q "^[^|]\\+|$(escape_pattern "$path")|" "$_objects_buffer"; then
                    __ "Fatal error: when truncating '%s', it wasn't found in the objects buffer" "$path" >&2
                    exit 3
                fi
                debug "${_ind}ignored\n"

            # truncate on a new file or a changed file
            elif grep -q "^$(escape_pattern "$path")\$" "$_newfiles_buffer"; then
                debug "${_ind}truncate on a new/changed file\n"
                debug "${_ind}ignored\n"

            # truncate on a recently extended file
            elif grep -q "^$(escape_pattern "$path")\$" "$_extfiles_buffer"; then
                debug "${_ind}truncate on a recently extended file\n"
                debug "${_ind}ignored\n"

            # regular truncate
            else
                debug ">>> %s: '%s'\n" "$op_changed" "$rel_path"
                echo "$op_changed: $rel_path" >> "$_out"
            fi
            ;;

        chown|chmod|set_xattr)
            if [ "$opt_with_props" = 'true' ]; then
                debug ">>> %s: '%s'\n" "$op_props" "$rel_path"
                echo "$op_props: $rel_path" >> "$_out"
            fi
            ;;

        rmdir|unlink)
            parent_fn="$(basename "$parent")"

            # was turned into an object before
            if is_temp_object "$fn"; then

                # searching for the destination of a previous rename
                if ! _match="$(grep "^[^|]\\+|[^|]\+|[^|]\+|$(escape_pattern "$path")|" "$_objects_buffer")"; then
                    __ "Fatal error: when deleting '%s', it wasn't found in the objects buffer" "$path" >&2
                    exit 3
                fi
                real_path="$(echo "$_match" | awk -F '|' '{print $2}')"
                debug "${_ind}deleting object '%s' which real path is '%s'\n" \
                    "$path" "$real_path"

                # if the file is a changed one
                if grep -q "^$(escape_pattern "$real_path")\$" "$_newfiles_buffer"; then
                    debug "${_ind}found '%s' in the new files buffer\n" "$real_path"
                    debug "${_ind}which means it is actually a changed file, so ignoring the deletion\n"

                # real deletion
                else
                    rel_path="$(echo "$_match" | awk -F '|' '{print $3}')"
                    debug ">>> %s: '%s'\n" "$op_deleted" "$rel_path"
                    echo "$op_deleted: $rel_path" >> "$_out"
                fi

            # unlinking in a object dir
            elif is_temp_object "$parent_fn"; then

                # searching for the destination of a previous rename
                if ! _match="$(grep "^[^|]\\+|[^|]\+|[^|]\+|$(escape_pattern "$parent")|" "$_objects_buffer")"; then
                    __ "Fatal error: when deleting '%s', it wasn't found in the objects buffer" "$path" >&2
                    exit 3
                fi
                real_path="$(echo "$_match" | awk -F '|' '{print $2}')"
                debug "${_ind}deleting in object dir '%s' which real path is '%s'\n" \
                    "$parent" "$real_path"
                debug "${_ind}ignoring\n"

            # not an object
            else
                debug ">>> %s: '%s'\n" "$op_deleted" "$rel_path"
                echo "$op_deleted: $rel_path" >> "$_out"
            fi

            # add it to the buffers
            if [ "$op" = 'rmdir' ]; then
                debug "${_ind}adding '%s' to deldirs buffer\n" "$path"
                echo "$path" >> "$_deldirs_buffer"
                debug "${_ind}adding '%s' to deldirs buffer\n" "$rel_path"
                echo "$rel_path" >> "$_deldirs_buffer"
            else
                debug "${_ind}adding '%s' to delfiles buffer\n" "$path"
                echo "$path" >> "$_delfiles_buffer"
                debug "${_ind}adding '%s' to delfiles buffer\n" "$rel_path"
                echo "$rel_path" >> "$_delfiles_buffer"
            fi
            ;;

        utimes)
            if [ "$opt_with_times" = 'true' ]; then
                debug ">>> %s: '%s'\n" "$op_times" "$rel_path"
                echo "$op_times: $rel_path" >> "$_out"
            fi
            ;;

        snapshot)
            # the compared snapshot directory (used for the function 'rel_path()'
            cmp_dir="$fn"
            debug "${_ind}define the compared directory to '%s'\n" "$cmp_dir"
            ;;

        *)
            debug ">>> unknown: %s\n" "$line"
            __ "Warning: unknown raw line '%s'" "$line" >&2
            ;;
    esac
done < "$_raw_diff"

debug "${_ind}current out:\n"
debug '%s\n' "${_ind}---"
debug '%s\n' "$(cat "$_out")"
debug '%s\n' "${_ind}---"

# clean after the deleted things

if [ -r "$_deldirs_buffer" ] && \
    [ "$(wc -l "$_deldirs_buffer" | awk '{print $1}')" -gt 0 ]
then
    debug "${_ind}deldirs buffer:\n"
    debug '%s\n' "${_ind}---"
    debug '%s\n' "$(sed "s/^/${_ind}/g" "$_deldirs_buffer")"
    debug '%s\n' "${_ind}---"

    while read -r _dir; do
        rel_dir="$(rel_path "$_dir")"
        while _match="$(grep -n "^ *\\w\\+: $(escape_pattern "$rel_dir")/" "$_out")"; do
            debug "${_ind}removing line: '%s'\n" "$(echo "$_match" | sed 's/^[0-9]\+: //')"
            line_num="$(echo "$_match" | awk -F ':' '{print $1}')"
            sed -e "${line_num}d" -i "$_out"
        done
    done < "$_deldirs_buffer"
fi

if [ -r "$_delfiles_buffer" ] && \
    [ "$(wc -l "$_delfiles_buffer" | awk '{print $1}')" -gt 0 ]
then
    debug "${_ind}delfiles buffer:\n"
    debug '%s\n' "${_ind}---"
    debug '%s\n' "$(sed "s/^/${_ind}/g" "$_delfiles_buffer")"
    debug '%s\n' "${_ind}---"

    while read -r _file; do
        rel_file="$(rel_path "$_file")"
        debug "${_ind}processing file '%s' (%s)\n" "$_file" "$rel_file"
        while _match_add="$(grep -n "^$op_added: $(escape_pattern "$rel_file")\$" "$_out")" && \
                _match_del="$(grep -n "^$op_deleted: $(escape_pattern "$rel_file")\$" "$_out")"
        do
            line_num_del="$(echo "$_match_del" | awk -F ':' '{print $1}')"
            line_num_add="$(echo "$_match_add" | awk -F ':' '{print $1}')"
            debug "${_ind}found deleted line '%d' and added line '%d'\n" \
                "$line_num_del" "$line_num_add"
            # TODO WHY ? => remove the skip ?
            if [ "$line_num_del" -ge "$line_num_add" ]; then
                debug "${_ind}skipping, because deletion was after addition\n"
                break
            fi
            debug "${_ind}removing line: '%s'\n" "$(echo "$_match_del" | sed 's/^[0-9]\+: //')"
            sed -e "${line_num_del}d" -i "$_out"
            debug "${_ind}replacing line: '%s'\n" "$(echo "$_match_add" | sed 's/^[0-9]\+: //')"
            line_num_rep="$((line_num_add - 1))"
            sed -e "${line_num_rep}s|^$op_added: |$op_changed: |g" -i "$_out"
        done
    done < "$_delfiles_buffer"
fi

# remove duplicate lines
_out_uniq="${_out}.uniq"
sort -u "$_out" > "$_out_uniq"
mv "$_out_uniq" "$_out"

# display the final diff result
cat "$_out"

# if it is asked to compare to standard diff (and option --file was not used)
if [ "$opt_compare_to_std_diff" = 'true' ] && [ "$opt_file" != 'true' ]; then
    debug ''
    debug "${_ind}will compare the result to the standard '%s' utility\n" 'diff'

    # if the "standard" 'diff' utility is available
    if command -v diff >/dev/null 2>&1; then
        debug "${_ind}standard '%s' utility found\n" 'diff'

        # un-translate the output
        debug "${_ind}untranslating the output\n"
        _out_untranslated="${_out}.C.raw"
        sed -e "s|^$op_added:|added:|g" -e "s|^$op_changed:|changed:|g" \
            -e "s|^$op_deleted:|deleted:|g" -e "s|^$op_renamed:|renamed:|g" \
            -e "s|^$op_props:|props:|g" -e "s|^$op_times:|times:|g" "$_out" \
            > "$_out_untranslated"

        # produce a diff using "standard" 'diff' utility
        echo
        __ "Producing a diff using standard '%s' utility ... (might takes a little time)" 'diff' \
            | sed 's/^/# /g'
        debug "${_ind}running: %s\n" "LC_ALL=C diff -rq '$_snap_ref' '$_snap_cmp'"
        _std_diff_out="${_out}.std.raw"
        LC_ALL=C diff -rq "$_snap_ref" "$_snap_cmp" > "$_std_diff_out" 2>/dev/null || true
        debug "${_ind}the standard '%s' utility analysis is:\n---\n%s\n---\n" 'diff' "$(cat "$_std_diff_out")"

        # normalize both outputs
        debug "${_ind}normalizing both outputs\n"
        _out_normalized="${_out_untranslated}.normalized"
        sed -e 's/^[ 	]*//g' "$_out_untranslated" -e '/^\(times\|prop\):/d' | sort > "$_out_normalized" || true
        _std_diff_out_normalized="${_std_diff_out}.normalized"
        sed -e "s|$(escape_pattern "$_snap_ref" | sed 's/|/\\|/g')|old|" \
            -e "s|$(escape_pattern "$_snap_cmp" | sed 's/|/\\|/g')|new|g" -e 's|: |/|' \
            -e 's/Only in new/added: /' -e 's/Only in old/deleted: /' \
            -e 's|Files old/.* and new/\(.*\) differ|changed: /\1|' \
            -e '/File .* is a fifo while file .* is a fifo/d' "$_std_diff_out" | sort > "$_std_diff_out_normalized"

        # compare the outputs
        debug "${_ind}comparing the outputs\n"
        _diff_compare="${_out}.comparison"
        _ret=0
        LC_ALL=C diff -u0 "$_out_normalized" "$_std_diff_out_normalized" > "$_diff_compare" || _ret="$?"
        if [ "$_ret" -gt 1 ]; then
            __ "Warning: failed to compare both diffs (using standard '%s')" 'diff' >&2
        else

            # collect the differences
            debug "${_ind}collecting the differences\n"
            _diff_out="${_out}.compared"
            _ret=0
            grep '^[+-][^+-]' "$_diff_compare" > "$_diff_out" || _ret="$?"
            debug "${_ind}differences are:\n---\n%s\n---\n" "$(cat "$_diff_out")"

            # print the comparison (re-translated)
            debug "${_ind}printing the comparison (re-translated)\n"
            if [ "$_ret" -eq 1 ]; then
                __ "Note: same output as with the standard '%s' utility" 'diff' | sed 's/^/# /g'
            elif [ "$_ret" -eq 0 ]; then
                __ "Comparison with standard '%s' utility :" 'diff' | sed 's/^/# /g'
                sed -e "s|^\\([+-]\\) *added:|\\1$op_added:|g" \
                    -e "s|^\\([+-]\\) *changed:|\\1$op_changed:|g" \
                    -e "s|^\\([+-]\\) *deleted:|\\1$op_deleted:|g" \
                    -e "s|^\\([+-]\\) *renamed:|\\1$op_renamed:|g" \
                    -e 's/^/# /g' \
                    "$_diff_out"
            else
                __ "Warning: failed to collect the differences between the two results" >&2
            fi
        fi
    else
        __ "Warning: can't compare to standard '%s' utility (binary not found)" 'diff' >&2
    fi
fi

# update the return code, 0 if there is no differences, 1 else
_ret=0
[ "$(wc -l "$_out" | awk '{print $1}')" -eq 0 ] || _ret="$?"

# exit with proper return code
exit "$_ret"
