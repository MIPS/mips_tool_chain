#!/bin/bash
#
# This script builds toolchain for mips-sde-elf target.
# Version 1.1
#
# -----------------------------------------------------------------------------
# Copyright (c) 2011, MIPS Technologies, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions, and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions, and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#   * Neither the name of MIPS Technologies, Inc. nor the
#     names of its contributors may be used to endorse or promote products
#     derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL MIPS TECHNOLOGIES, INC. BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES, LOSS OF USE, DATA, OR PROFITS, OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# -----------------------------------------------------------------------------

# Setup default packages versions
gmp_base=gmp-4.3.2
mpc_base=mpc-0.9
mpfr_base=mpfr-3.0.1
binutils_base=binutils-2.21.1
gcc_base=gcc-4.4.6
newlib_base=newlib-1.19.0
gdb_base=gdb-7.2

# Script name and path
prg=`basename "$0"`
wdr=$(readlink -f `dirname "$0"`)

# Setup arch and target names
arch="mips"

# Initialize script settings by default values
cmds=("buildall")
prefix="$PREFIX"
dld_dir="$PWD"/dl
src_dir="$PWD"/src
bld_dir="$PWD"/bld
int_inst_dir="$PWD"/install
make_opts=""

# Print script usage info
function usage() {
    echo "Usage: $prg [OPTIONS] COMMANDS"
    echo ""
    echo "COMMANDS"
    echo "    buildall            run all building stages from unpack to check"
    echo "    download            check packages and download missed ones"
    echo "    cleanup             remove source, build and aux dirs"
    echo "    help                print this help message"
    echo ""
    echo "    unpack              unpack packages"
    echo "    buildgmp            build GMP library"
    echo "    buildmpfr           build MPFR library"
    echo "    buildmpc            build MPC library"
    echo "    buildbinutils       build Binutils"
    echo "    buildgcc1           build GCC phase I"
    echo "    buildnewlib         build Newlib libary"
    echo "    buildgcc2           build GCC phase II"
    echo "    buildgdb            build GDB"
    echo "    check               run set of simple tests"
    echo ""
    echo "OPTIONS"
    echo "    -h, --help          print this help message"
    echo "    -a, --arch=ARCH     build the toolchain for ARCH architecture"
    echo "                        accepted 'mips' or 'mipsel'"
    echo "    -p, --prefix=DIR    use DIR as an installation prefix"
    echo "    -d, --download=DIR  lookup packages tarballs in the DIR"
    echo "    -s, --source=DIR    use DIR to unpack packages tarballs"
    echo "    -b, --build=DIR     use DIR as a build directory"
    echo ""
    echo "ENVIRONMENT"
    echo "    You can override default packages versions using the following"
    echo "    environment variables. For example 'GMP_VER=5.5.5 $prg'."
    echo "    GMP_VER             gmp library version"
    echo "    MPC_VER             mpc library version"
    echo "    MPFR_VER            mpfr library version"
    echo "    BINUTILS_VER        binutils version"
    echo "    GCC_VER             gcc version"
    echo "    NEWLIB_VER          newlib library version"
    echo "    GDB_VER             gdb version"
}

# Parse command line arguments
function parse_args() {
    local opts=`getopt -n "$prg" \
             --long help,arch:,prefix:,download:,source:,build: \
             -o ha:p:d:s:b: \
             -- "$@"`

    if [ $? != 0 ] ; then
        echo "Error: Cannot parse command line" >&2
        usage
        exit 1
    fi

    eval set -- "$opts"

    while true ; do
        case "$1" in
            -h|--help) cmd=("help") ; shift ;;
            -a|--arch) arch="$2" ; shift 2 ;;
            -p|--prefix) prefix="$(readlink -f $2)" ; shift 2 ;;
            -d|--download) dld_dir="$(readlink -f $2)" ; shift 2 ;;
            -s|--source) src_dir="$(readlink -f $2)" ; shift 2 ;;
            -b|--build) bld_dir="$(readlink -f $2)" ; shift 2 ;;
            --) shift ; break ;;
            *) echo "Error: Cannot parse command line" >&2 ; usage ; exit 1 ;;
        esac
    done

    if [ $# -gt 0 ] ; then
        cmds=($@)
    fi
}

# Check configuration options
function check_cfg() {
    if [ ! -d "$prefix" ] ; then
        echo "Error: The installation prefix folder is a mandatory" >&2
        echo "argument. Use either PREFIX environment variable" >&2
        echo "or --prefix option to point to the existing directory." >&2
        exit 1
    fi

    if [ ! -d "$dld_dir" ] ; then
        echo "Error: Download directory should exist and contain" >&2
        echo "packages tarballs. Use --download option to provide" >&2
        echo "a path to this folder." >&2
        exit 1
    fi

    if [ "$arch" != "mips" ] && [ "$arch" != "mipsel" ] ; then
        echo "Error: unknown target architecture name '$arch'." >&2
        echo "Accepted values are: mips or mipsel." >&2
        exit 1
    fi

    test -d "$src_dir" || mkdir -p "$src_dir" || exit 1
    test -d "$bld_dir" || mkdir -p "$bld_dir" || exit 1
    test -d "$int_inst_dir" || mkdir -p "$int_inst_dir" || exit 1
}

# Print begin stage message, run function, check result and
# print error or end stage message
function run_stage() {
    local func="$1"
    local msg="$2"

    echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
    echo "%%% $msg"

    eval "$func" || \
        { echo "Failed: $msg" ; exit 1 ; }
}

# Override default packages versions using environment variables
function setup_packages_versions() {
    test -z "$GMP_VER" || gmp_base="gmp-$GMP_VER"
    test -z "$MPC_VER" || mpc_base="mpc-$MPC_VER"
    test -z "$MPFR_VER" || mpfr_base="mpfr-$MPFR_VER"
    test -z "$BINUTILS_VER" || binutils_base="binutils-$BINUTILS_VER"
    test -z "$GCC_VER" || gcc_base="gcc-$GCC_VER"
    test -z "$NEWLIB_VER" || newlib_base="newlib-$NEWLIB_VER"
    test -z "$GDB_VER" || gdb_base="gdb-$GDB_VER"
}

# Unpack everything
function unpack_packages() {
    cd $src_dir
    tar vfxj ${dld_dir}/"${gmp_base}.tar.bz2" && \
    tar vfxj ${dld_dir}/"${mpfr_base}.tar.bz2" && \
    tar vfxz ${dld_dir}/"${mpc_base}.tar.gz" && \
    tar vfxj ${dld_dir}/"${binutils_base}.tar.bz2" && \
    tar vfxj ${dld_dir}/"${gcc_base}.tar.bz2" && \
    tar vfxz ${dld_dir}/"${newlib_base}.tar.gz" && \
    tar vfxj ${dld_dir}/"${gdb_base}.tar.bz2" || \
    return 1
}

# Build GMP library
function build_gmp_lib() {
    cd $bld_dir
    mkdir $gmp_base
    cd $gmp_base
    ${src_dir}/${gmp_base}/configure \
        --prefix=${int_inst_dir}/${gmp_base} \
        --disable-shared && \
    make ${make_opts} && \
    make ${make_opts} install
}

# Build MPFR library
function build_mpfr_lib() {
    cd $bld_dir
    mkdir $mpfr_base
    cd $mpfr_base
    ${src_dir}/${mpfr_base}/configure \
        --prefix=${int_inst_dir}/${mpfr_base} \
        --disable-shared \
        --with-gmp=${int_inst_dir}/${gmp_base} && \
    make ${make_opts} && \
    make ${make_opts} install
}

# Build MPC library
function build_mpc_lib() {
    cd $bld_dir
    mkdir $mpc_base
    cd $mpc_base
    ${src_dir}/${mpc_base}/configure \
        --prefix=${int_inst_dir}/${mpc_base} \
        --disable-shared \
        --with-gmp=${int_inst_dir}/${gmp_base} \
        --with-mpfr=${int_inst_dir}/${mpfr_base} && \
    make ${make_opts} && \
    make ${make_opts} install
}

# Build binutils
function build_binutils() {
    cd $bld_dir
    mkdir $binutils_base
    cd $binutils_base
    ${src_dir}/${binutils_base}/configure \
        --prefix=$prefix \
        --target=$target && \
    make ${make_opts} && \
    make ${make_opts} install
}

# Build GCC phase 1
function build_gcc_p1() {
    cd $bld_dir
    mkdir ${gcc_base}-initial
    cd ${gcc_base}-initial
    ${src_dir}/${gcc_base}/configure \
        --prefix=$prefix \
        --target=$target \
        --with-gmp=${int_inst_dir}/${gmp_base} \
        --with-mpfr=${int_inst_dir}/${mpfr_base} \
        --with-mpc=${int_inst_dir}/${mpc_base} \
        --with-gnu-as --with-gnu-ld --enable-languages=c,c++ \
        --with-arch=mips32r2 --with-mips-plt --with-synci --with-llsc \
        --with-newlib --without-headers && \
    make ${make_opts} all-gcc && \
    make ${make_opts} install-gcc
}

# Build Newlib
function build_newlib() {
    cd $bld_dir
    mkdir ${newlib_base}
    cd ${newlib_base}
    ${src_dir}/${newlib_base}/configure \
        --prefix=$prefix \
        --target=$target && \
    make ${make_opts} && \
    make ${make_opts} install
}

# Build GCC phase 2
function build_gcc_p2() {
    cd $bld_dir
    mkdir ${gcc_base}-final
    cd ${gcc_base}-final
    ${src_dir}/${gcc_base}/configure \
        --prefix=$prefix \
        --target=$target \
        --with-gmp=${int_inst_dir}/${gmp_base} \
        --with-mpfr=${int_inst_dir}/${mpfr_base} \
        --with-mpc=${int_inst_dir}/${mpc_base} \
        --with-gnu-as --with-gnu-ld --enable-languages=c,c++ \
        --with-arch=mips32r2 --with-mips-plt --with-synci --with-llsc \
        --with-newlib && \
    make ${make_opts} all && \
    make ${make_opts} install
}

# Build gdb
function build_gdb() {
    cd $bld_dir
    mkdir ${gdb_base}
    cd ${gdb_base}
    ${src_dir}/${gdb_base}/configure \
        --prefix=$prefix \
        --target=$target \
        --with-gmp=${int_inst_dir}/${gmp_base} \
        --with-mpfr=${int_inst_dir}/${mpfr_base} \
        --with-mpc=${int_inst_dir}/${mpc_base} \
        --with-gnu-as --with-gnu-ld \
        --enable-languages=c,c++ --with-arch=mips32r2 --with-mips-plt \
        --with-synci --with-llsc  && \
    make ${make_opts} && \
    make ${make_opts} install
}

# Run a set of simple smoke tests
function run_smoke_tests() {
    cd $bld_dir

    rm -rf tests && mkdir tests && cd tests

cat > hello.c <<END_OF_HELLO_C
#include <stdio.h>

int main(int argc, const char *argv[])
{
    printf("Hello World!\n");
    return 0;
}
END_OF_HELLO_C

    # create load script
    sed 's/"elf32-littlemips", "elf32-bigmips", "elf32-littlemips"/"elf32-tradlittlemips", "elf32-tradbigmips", "elf32-tradlittlemips"/' ${src_dir}/${newlib_base}/libgloss/mips/idt32.ld > sde32.ld

    ${prefix}/bin/mips-sde-elf-gcc -T./sde32.ld hello.c -o hello -g || \
        return 1
    ${prefix}/bin/mips-sde-elf-run hello || \
        return 1

    # run gdb
cat > commands <<END_OF_GDB_CMDS
break main
target sim
load
run
next
next
next
next
quit
END_OF_GDB_CMDS

    ${prefix}/bin/mips-sde-elf-gdb -x commands ./hello || \
        return 1
}

# Remove source, build and all aux directories
function cleanup() {
    rm -rf "$src_dir" "$bld_dir" "$int_inst_dir"
}

# Download missed packages
function download() {
    local wget_opts="-t 10 -nv"

    if [ ! -e "${dld_dir}/${gmp_base}.tar.bz2" ] ; then
        wget ${wget_opts} -O "${dld_dir}/${gmp_base}.tar.bz2" \
            ftp://ftp.gmplib.org/pub/${gmp_base}/${gmp_base}.tar.bz2 || \
        return 1
    fi

    if [ ! -e "${dld_dir}/${mpfr_base}.tar.bz2" ] ; then
        wget ${wget_opts} -O "${dld_dir}/${mpfr_base}.tar.bz2" \
            http://www.mpfr.org/${mpfr_base}/${mpfr_base}.tar.bz2 || \
        return 1
    fi

    if [ ! -e "${dld_dir}/${mpc_base}.tar.gz" ] ; then
        wget ${wget_opts} -O "${dld_dir}/${mpc_base}.tar.gz" \
            http://www.multiprecision.org/mpc/download/${mpc_base}.tar.gz || \
        return 1
    fi

    if [ ! -e "${dld_dir}/${binutils_base}.tar.bz2" ] ; then
        wget ${wget_opts} -O "${dld_dir}/${binutils_base}.tar.bz2" \
            http://ftp.gnu.org/gnu/binutils/${binutils_base}.tar.bz2 || \
        return 1
    fi

    if [ ! -e "${dld_dir}/${gcc_base}.tar.bz2" ] ; then
        wget ${wget_opts} -O "${dld_dir}/${gcc_base}.tar.bz2" \
            ftp://ftp.gnu.org/gnu/gcc/${gcc_base}/${gcc_base}.tar.bz2 || \
        return 1
    fi

    if [ ! -e "${dld_dir}/${newlib_base}.tar.gz" ] ; then
        wget ${wget_opts} -O "${dld_dir}/${newlib_base}.tar.gz" \
            ftp://sources.redhat.com/pub/newlib/${newlib_base}.tar.gz || \
        return 1
    fi

    if [ ! -e "${dld_dir}/${gdb_base}.tar.bz2" ] ; then
        wget ${wget_opts} -O "${dld_dir}/${gdb_base}.tar.bz2" \
            http://ftp.gnu.org/gnu/gdb/${gdb_base}a.tar.bz2 || \
        return 1
    fi
}

# Run commands
function run_commands() {
    declare -a cmds=("${!1}")

    all_cmds=("unpack" "buildgmp" "buildmpfr" "buildmpc"
              "buildbinutils" "buildgcc1" "buildnewlib" "buildgcc2"
              "buildgdb" "check")

    for cmd in "${cmds[@]}"; do
        case "$cmd" in
            help)
                usage
                ;;
            cleanup)
                run_stage "cleanup" "Cleanup intermediate folders"
                ;;
            download)
                run_stage "download" "Download missed packages"
                ;;
            buildall)
                run_commands all_cmds[@]
                ;;
            unpack)
                run_stage "unpack_packages" "Unpack packages"
                ;;
            buildgmp)
                run_stage "build_gmp_lib" "Build GMP library"
                ;;
            buildmpfr)
                run_stage "build_mpfr_lib" "Build MPFR library"
                ;;
            buildmpc)
                run_stage "build_mpc_lib" "Build MPC library"
                ;;
            buildbinutils)
                run_stage "build_binutils" "Build Binutils"
                ;;
            buildgcc1)
                run_stage "build_gcc_p1" "Build GCC phase I"
                ;;
            buildnewlib)
                run_stage "build_newlib" "Build Newlib library"
                ;;
            buildgcc2)
                run_stage "build_gcc_p2" "Build GCC phase II"
                ;;
            buildgdb)
                run_stage "build_gdb" "Build GDB"
                ;;
            check)
                run_stage "run_smoke_tests" "Test toolchain"
                ;;
            *)
                echo "Error: Unknown command" >&2
                usage
                exit 1
                ;;
        esac
    done
}

parse_args "$@"

if [ "${cmds[0]}" != "help" -o ${#cmds[@]} -gt 1 ] ; then
    check_cfg

    export PATH=$prefix/bin:$PATH
    target="${arch}-sde-elf"

    setup_packages_versions
fi

run_commands cmds[@]
