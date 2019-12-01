#!/bin/bash
# Run a testcase on a remote system, via ssh.
# Copyright (C) 2012-2016 Free Software Foundation, Inc.
# This file is part of the GNU C Library.

# The GNU C Library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.

# The GNU C Library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General Public
# License along with the GNU C Library; if not, see
# <http://www.gnu.org/licenses/>.


##############
# This is a local copy of scripts/cross-test-ssh.sh from the glibc
# repository, it skips some files that go into infinite loops so
# that the testsuite finishs and it also does some extra 'touch'
# commands to avoid NFS problems.
#
# The NFS problems are due to the fact that we (Imagination) do
# not use the noac or actimeo=0 options.  This means that when
# running the testsuite on a host machine (an x86 linux box),
# we may ssh a command on the target machine (a MIPS box) and
# that command may create a new file on the NFS filesystem that
# the two machines share.  That file may not be immediately visible
# on the host machine where the make command being run to do testing
# expects to see it.  This will result in a 'No such file or directory'
# error and the glibc testing will abort without giving a list of
# passed and failed tests.  This script hacks around the problem
# by doing touch commands on the directories where the new files
# were created before trying to access the new files.  This invalidates
# the cache entries and fixes the problem.   There are currently
# two places where this is known to happen, once when running localedef
# in the localedata testing and once when running zic in the timezone
# testing.  This would be easier to fix in the glibc makefiles but
# patches for that were rejected.
# See: https://sourceware.org/ml/libc-alpha/2016-02/msg00356.html
##############

# usage: cross-test-ssh.sh [--ssh SSH] HOST COMMAND ...
# Run with --help flag to get more detailed help.

progname="$(basename $0)"

usage="usage: ${progname} [--ssh SSH] HOST COMMAND ..."
help="Run a glibc test COMMAND on the remote machine HOST, via ssh,
preserving the current working directory, and respecting quoting.

If the '--ssh SSH' flag is present, use SSH as the SSH command,
instead of ordinary 'ssh'.

If the '--timeoutfactor FACTOR' flag is present, set TIMEOUTFACTOR on
the remote machine to the specified FACTOR.

To use this to run glibc tests, invoke the tests as follows:

  $ make test-wrapper='ABSPATH/cross-test-ssh.sh HOST' tests

where ABSPATH is the absolute path to this script, and HOST is the
name of the machine to connect to via ssh.

If you need to connect to the test machine as a different user, you
may specify that just as you would to SSH:

  $ make test-wrapper='ABSPATH/cross-test-ssh.sh USER@HOST' tests

Naturally, the remote user must have an appropriate public key, and
you will want to ensure that SSH does not prompt interactively for a
password on each connection.

HOST and the build machines (on which 'make check' is being run) must
share a filesystem; all files needed by the tests must be visible at
the same paths on both machines.

${progname} runs COMMAND in the same directory on the HOST that
${progname} itself is run in on the build machine.

The command and arguments are passed to the remote host in a way that
avoids any further shell substitution or expansion, on the assumption
that the shell on the build machine has already done them
appropriately."

ssh='ssh'
timeoutfactor=$TIMEOUTFACTOR
while [ $# -gt 0 ]; do
  case "$1" in

    "--ssh")
      shift
      if [ $# -lt 1 ]; then
        break
      fi
      ssh="$1"
      ;;

    "--timeoutfactor")
      shift
      if [ $# -lt 1 ]; then
        break
      fi
      timeoutfactor="$1"
      ;;

    "--help")
      echo "$usage"
      echo "$help"
      exit 0
      ;;

    *)
      break
      ;;
  esac
  shift
done

if [ $# -lt 1 ]; then
  echo "$usage" >&2
  echo "Type '${progname} --help' for more detailed help." >&2
  exit 1
fi

host="$1"; shift

## These tests take a long time and many just time out, you might
## want to uncomment this test to speed up the runs.
#if [[ "$@" == *"/nptl/"* ]]; then
#  exit 1
#fi

# This test goes into an infinite loop
if [[ "$@" == *"/tst-sem11"* ]]; then
  exit 1
fi

# This test goes into an infinite loop
if [[ "$@" == *"/tst-mode-switch-1" ]]; then
  exit 1
fi
# This test goes into an infinite loop
if [[ "$@" == *"/tst-mode-switch-2" ]]; then
  exit 1
fi

if [[ "$@" != *"/localedef"* ]]; then
  localedir=""
else
  arg=${@:$#}
  localedir=`dirname $arg`
fi

if [[ "$@" != *"/zic"* ]]; then
  tzdir=""
else
  i=0
  for arg in "$@"; do
    if [[ "$i" == "1" ]]; then
      tzdir="$arg"
      break
    fi
    if [[ "$arg" == "-d" ]]; then
      i=1
    fi
  done
fi

# Create libgcc_s.so and libstdc++.so links so that nptl tests do
# not fail.

# This could be a race condition in parallel makes.

for arg in "$@"; do
  if [[ "$arg" == *"/ld.so.1" ]]; then
    t=`dirname $arg`
    linkdir=`dirname $t`
    break;
  fi
done

#if [[ "$linkdir" != "" ]]; then
#  if [ ! -e $linkdir/libgcc_s.so ]; then
#    (
#      # Need to look in $linkdir/config.make to find CC and CFLAGS
#      # but that is a make include file, it cannot be included here.
#      libgcc_link=`$CC $CFLAGS --print-file-name=libgcc_s.so`
#      libstd_link=`$CC $CFLAGS --print-file-name=libstdc++.so`
#      if [ ! -e $linkdir/libgcc_s.so ]; then
#        ln -s $libgcc_link $linkdir/libgcc_s.so
#      fi
#      if [ ! -e $linkdir/libstdc++.so ]; then
#        ln -s $libstd_link $linkdir/libstdc++.so
#      fi
#    )
#  fi
#fi

# Print the sequence of arguments as strings properly quoted for the
# Bourne shell, separated by spaces.
bourne_quote ()
{
  local arg qarg
  for arg in "$@"; do
    qarg=${arg//\'/\'\\\'\'}
    echo -n "'$qarg' "
  done
}

# Transform the current argument list into a properly quoted Bourne shell
# command string.
command="$(bourne_quote "$@")"

# Add command to set the current directory.
command="cd $(bourne_quote "$PWD")
${command}"

# Add command to set the timeout factor, if required.
if [ "$timeoutfactor" ]; then
  command="export TIMEOUTFACTOR=$(bourne_quote "$timeoutfactor")
${command}"
fi

# HOST's sshd simply concatenates its arguments with spaces and
# passes them to some shell.  We want to force the use of /bin/sh,
# so we need to re-quote the whole command to ensure it appears as
# the sole argument of the '-c' option.
full_command="$(bourne_quote "${command}")"
$ssh "$host" /bin/sh -c "$full_command"
ret=$?

if [[ "$localedir" != "" ]]; then
  touch $localedir
fi

if [[ "$tzdir" != "" ]]; then
  touch $tzdir
fi

exit $ret
