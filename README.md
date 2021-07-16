# btrfs-diff-sh

Analyze differences between two BTRFS snapshots (like
[GNU diff](https://www.gnu.org/software/diffutils/manual/) for directories).

It is a single file *POSIX* shell script of ~ 570 lines of code (without blanks and comments).

![Release](https://img.shields.io/github/v/release/mbideau/btrfs-diff-sh)
![Release Date](https://img.shields.io/github/release-date/mbideau/btrfs-diff-sh)  
[![Build](https://github.com/mbideau/btrfs-diff-sh/actions/workflows/build.yml/badge.svg)](https://github.com/mbideau/btrfs-diff-sh/actions/workflows/build.yml)
[![Shellcheck](https://github.com/mbideau/btrfs-diff-sh/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/mbideau/btrfs-diff-sh/actions/workflows/shellcheck.yml)
![Shell POSIX](https://img.shields.io/badge/shell-POSIX-darkgreen)  
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](http://www.gnu.org/licenses/gpl-3.0)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg)](CODE_OF_CONDUCT.md)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://conventionalcommits.org)


## USAGE

This is the output of `btrfs-diff --help` :

```text

btrfs-diff - get differences between two BTRFS snapshots.

USAGE

    btrfs-diff SNAP_REF SNAP_CMP [ -t | --with-times ] [ -p | --with-props ]
    btrfs-diff -f|--file DUMP_FILE [ -t | --with-times ] [ -p | --with-props ]

    btrfs-diff [ -h | --help ]
    btrfs-diff [ -v | --version ]


ARGUMENTS

    SNAP_REF
        Path to the reference snapshot.
        It must be a read-only one.

    SNAP_CMP
        Path to the compared snapshot.
        It must also be a read-only one.

    DUMP_FILE
        A file containing the output of the command 'LC_ALL=C btrfs receive --quiet --dump'.


OPTIONS

    -d | --compare-to-std-diff
        Compare the result against the output of the standard 'diff' utility.
        This option is ignored when the option '--file' is also specified.

    -f | --file
        Instead of two snapshots, use a file containing the send/receive output of the snapshots.

    -t | --with-times
        Report times differences (atime, mtime, ctime)

    -p | --with-props
        Report properties differences (chmod, chown, set_xattr)

    -h | --help
        Display help message.

    -v | --version
        Display version and license informations.


EXAMPLES

    Get the differences between two snapshots.
    $ btrfs-diff /backup/btrfs-sp/rootfs/2020-12-25_22h00m00.shutdown.safe \
        /backup/btrfs-sp/rootfs/2019-12-25_21h00m00.shutdown.safe


    Create the dump of the send/receive between two snapshots.
    $ btrfs send --quiet --no-data -p /backup/btrfs-sp/rootfs/2020-12-25_22h00m00.shutdown.safe \
        /backup/btrfs-sp/rootfs/2019-12-25_21h00m00.shutdown.safe \
        | LC_ALL=C btrfs receive --quiet --dump > /tmp/btrfs.dump

    Get the differences between two snapshots.
    $ btrfs-diff --file /tmp/btrfs.dump


ENVIRONMENT

    DEBUG
        Print debugging information to 'STDERR' only if var DEBUG='btrfs-diff'.

    LANGUAGE
    LC_ALL
    LANG
    TEXTDOMAINDIR
        Influence the translation.
        See GNU gettext documentation.


AUTHORS

    Written by: Michael Bideau


REPORTING BUGS

    Report bugs to: <https://github.com/mbideau/btrfs-diff-sh/issues>


COPYRIGHT

    Copyright © 2020-2021 Michael Bideau.
    License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>
    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.


SEE ALSO

    Home page: <https://github.com/mbideau/btrfs-diff-sh>

```


## Installation

### Using `git` and `make`

Install the required dependencies (example for *Debian* / *Ubuntu*)

```sh
~> sudo apt install make gettext gzip tar grep sed mawk coreutils
```

Install [gimme-a-man](https://github.com/mbideau/gimme-a-man), to be able to generate the manual
pages.  
It needs to be in the *PATH*.

Get the sources

```sh
~> git clone -q https://github.com/mbideau/btrfs-diff-sh
~> cd btrfs-diff
~> make install
```

This will install it to `/usr/local/bin/btrfs-diff`.

If you want to install it to /usr/bin, just replace the last instruction by :  

```sh
~> make install prefix=/usr
```

### The raw / hacker way, using `wget` or `curl`

Extract the SHELL script from the repository :

```sh
~> wget "https://raw.githubusercontent.com/mbideau/btrfs-diff-sh/main/btrfs_diff.sh" /usr/local/bin/btrfs-diff
~> chmod +x /usr/local/bin/btrfs-diff
```

You will not have the translations though, which could prevent you to correctly handle translated
`--help` message.


## Fast diff between BTRFS snapshots

### Why ? Reason to be

The great advantage of having a [COW filesystem](https://en.wikipedia.org/wiki/Copy-on-write) with
snapshoting like BTRFS is that producing the differences between two snapshots is almost
instantaneous.

For example, you can get the differences between *snap1* and *snap2* with the following command :

```sh
~> btrfs send --quiet --no-data -p snap1 snap2 | LC_ALL=C btrfs receive --quiet --dump > /tmp/btrfs.dump
```

Note that this dump is not really human readable. Moreover it contains operations, not differences.
So it is not exactly what we are looking for. For example it might contains transient object
informations, and multiple lines of unintuitive operations to reproduce a file state.

I wanted a differences file format like the one you have when doing `diff -rq` or
`git status --short`, in short: a human friendly one.

I looked at the prior art (see below), but nothing were satisfying enough, so I rolled my own
diff utility (which just produce then parse that dump file format).


### Prior art analysis

As the time of writing this (i.e.: Dec. 2020), I have found 2 projects matching `btrfs diff`
in *Github* and 0 in *Gitlab*.

* [btrfs-send-go](https://github.com/bucko909/btrfs-send-go) [GO]  
  Raw, and have minor bugs, but does exactly the job.  
  I have improved it in [my own fork](https://github.com/mbideau/btrfs-diff-go), but it seems to
  crash on *clone* instructions.  
  Also, having a compiled binary, is not super hackable (even a tiny one like this) and at
  deployment time, it might miss some dependencies (I have managed to build it statically but it
  doesn't work in my *initram*, I have not found out why).  
  Finally it was not translatable (as-is).

* [btrfs-snapshots-diff](https://github.com/sysnux/btrfs-snapshots-diff) [Python 2]  
  It has a lot of issues (with link, but not only), and is Python 2, which is deprecated by now.  
  No go.

* [btrfs-snapshots-diff](https://github.com/daviessm/btrfs-snapshots-diff)  [Python 3]  
  A fork of the previous one, with a lot of issues fixed and in *Python 3*.  
  Because it is written in *Python*, it means that if I want to run it in *initram* (I do) I
  will need to include the *Python* binary and the required dependencies. Too much for what I
  want.  
  May be I could compile it with *Cython*, but I am not (yet) comfortable with that.

There is also the [snapper](https://github.com/openSUSE/snapper) utility that compares BTRFS
snapshots, but it does so by mounting both snapshots and doing a "standard" `diff` on them (if my
understanding is correct).

Finally I have found a lot of small Python script doing a BTRFS diff, but they were using a
hacky way to do it (based on the `find-new` method), without being able to catch deletions.  
They were better-than-nothing prior to `btrfs send` and `btrfs receive`, but they are obsolete
since. Hence, I skipped all those.

So, I almost found what I wanted, after patching/fixing *btrfs-send-go* but I was not confident
enough to trust it, and it still lacked the translation layer, plus possible deployment issues (in
*initram*).


### Solution

Once I decided that I was going to write my own program to do the same job, but better for my use
case, I had to come up with a way to parse the output of the `btrfs receive --dump` command in order
to produce a human friendly diff.

#### Output formatting

For the output format, I choose a simple one:  

```text
 operation: file
 operation: file
 …
```

Where `operation` is the (eventually translated) name of the operation, and `file` is the path of
the file impacted.

For example it could produce something like:  

```text
  added: /testdir
  times: /
  added: /testdir/file.txt
  times: /testdir
  props: /testdir/otherfile.txt
deleted: /testdir/temp_file.tmp
  times: /testdir
changed: /testdir/result.log
  times: /testdir
```

Operations on *times* and *properties* (*props*) are not reported by default. You have to enable
them with options `--with-times` and `--with-props`.

#### Parsing: POSIX SHELL reading line by line the raw dump file

I've chosen to write a POSIX SHELL script because it is one of the most portable format, and I
needed that portability to use it in *initram*.

The script is not really efficient, because it does many IO, and it is totally not optimized, but it
does a decent job (1 to few seconds).  
I don't feel any need to go for a few seconds to few milliseconds.  
People looking for a more efficient parser, should go with the *Go* version noted in the Prior Art
section.

As expected, it was tricky to get this working because there many small subtleties in the raw
format.  
Note that, by using temporary files as buffers, I manage to only parse the file once.  
There is a minor re-tweaking of the resulting file though, to delete lines matching operations on
deleted files/directories.


#### Features list

Cool features implemented :

* can produce the raw diff from two snapshots or just parse a raw dump file
* fully translated even the operation names (for now, only in french)
* produces an output close to the `diff -rq` utility and `git status --short`
* can compare its result with the one from the `diff` utility

Technical features :

* [KISS](https://simple.wikipedia.org/wiki/KISS_(principle)): simple construction with a few
  lines of SHELL, with no dependency (except some *GNU coreutils* binaries)
* portable *POSIX SHELL*, syntaxicaly checked with `shellcheck`
* *Makefile* that automatically build locales and man pages, but also `dist` to get a tarball of the
  sources
* have debugging with environment variable `DEBUG=btrfs-diff`

#### Limits / flaws

It does the job, but have some limits.

It is slow and doing many IO by using 5 temporary files as buffers.

It was not tested on huge dumps, so it might not perform well or reveal majors bugs.

Due to BTRFS implementation, some files appear as *changed*, when they are not (according to
`diff` utility). I have absolutely no idea why BTRFS is acting like this… If someone can
help me figures this out, I'll be glad.
It turns out [btrfs-send-go](https://github.com/bucko909/btrfs-send-go) is having the same
issue.


## Test it : its portable SHELL after all, just one `wget`/`curl` away

The best I can recommend is try it out, and see for yourself if it matches your needs.


## Feedbacks wanted, PR/MR welcome

If you have any question or wants to share your uncovered case, please I be glad to answer and
accept changes through *Pull Request*.


## Developing

Do your changes, then, in the source directory, just run :  

```sh
~> make
```

## Testing

And to be sure that the program is working in your environment, or that you have not broken
anything while developing, you have to run the tests.

In order to do that, you will need to have [shunit2](https://github.com/kward/shunit2/) installed
somewhere.  

```sh
~> git clone -q https://github.com/kward/shunit2 .shunit2
```

NOTE: if you install *shunit2* in the .tmp directory, it will be deleted when doing a `make clean`.

Then you can run the following command:  

```sh
~> SHUNIT2=.shunit2 make test
```


## Distribution

If you want a clean tarball of the sources, you can run :  

```sh
~> make dist
```


## Copyright and License GPLv3

Copyright © 2020-2021 Michael Bideau [France]

This file is part of *btrfs-diff-sh*.

*btrfs-diff-sh* is free software: you can redistribute it and/or modify it under the terms of the GNU
General Public License as published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

*btrfs-diff-sh* is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License along with btrfs-diff-sh. If not,
see [https://www.gnu.org/licenses/](https://www.gnu.org/licenses/).



## Code of conduct

Please note that this project is released with a *Contributor Code of Conduct*. By participating in
this project you agree to abide by its terms.
