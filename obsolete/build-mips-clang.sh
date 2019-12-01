#!/bin/bash
#
# This script builds llvm/clang for mips target platform.
# Version 1.2
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
llvm_base=llvm-3.0
clang_base=clang-3.0

# Script name and path
prg=`basename "$0"`
wdr=$(readlink -f `dirname "$0"`)

# Initialize script settings by default values
cmds=("buildall")
prefix="$PREFIX"
dld_dir="$PWD"/dl
src_dir="$PWD"/src
bld_dir="$PWD"/bld
make_opts=""
is_debug="no"

# Setup arch and target names
host=""   # x86_64-linux-gnu
target="" # mips-linux-gnu
build=""  # x86_64-linux-gnu

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
    echo "    buildclang          build llvm/clang"
    echo "    check               run set of simple tests"
    echo ""
    echo "OPTIONS"
    echo "    -h, --help          print this help message"
    echo "    --host=HOST         use HOST as a host platform"
    echo "    --target=TARGET     use TARGET as a target platform"
    echo "    --debug             build debug version of llvm/clang"
    echo "    -p, --prefix=DIR    use DIR as an installation prefix"
    echo "    -d, --download=DIR  lookup packages tarballs in the DIR"
    echo "    -s, --source=DIR    use DIR to unpack packages tarballs"
    echo "    -b, --build=DIR     use DIR as a build directory"
    echo "    -j, --jobs=NUM      run NUM make jobs simultaneously"
    echo ""
    echo "ENVIRONMENT"
    echo "    You can override default packages versions using the following"
    echo "    environment variables. For example 'LLVM_VER=2.9 $prg'"
    echo "    or 'LLVM_VER=trunk $prg'."
    echo "    LLVM_VER            llvm version"
    echo "    CLANG_VER           clang version"
}

# Parse command line arguments
function parse_args() {
    local opts=`getopt -n "$prg" \
             --long help,debug,host:,target:,prefix:,download:,source:,build:,jobs: \
             -o hp:d:s:b:j: \
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
            --debug) is_debug="yes" ; shift ;;
            --host) host="$2" ; shift 2 ;;
            --target) target="$2" ; shift 2 ;;
            -p|--prefix) prefix="$(readlink -f $2)" ; shift 2 ;;
            -d|--download) dld_dir="$(readlink -f $2)" ; shift 2 ;;
            -s|--source) src_dir="$(readlink -f $2)" ; shift 2 ;;
            -b|--build) bld_dir="$(readlink -f $2)" ; shift 2 ;;
            -j|--jobs) make_opts="--jobs=$2" ; shift 2 ;;
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

    test -d "$src_dir" || mkdir -p "$src_dir" || exit 1
    test -d "$bld_dir" || mkdir -p "$bld_dir" || exit 1
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

# Print url to llvm Subversion repository
function get_llvm_svn_url() {
    if [ "$llvm_base" = "llvm-trunk" ] ; then
        echo "http://llvm.org/svn/llvm-project/llvm/trunk"
    else
        local ver=`echo "$llvm_base" | sed 's/llvm-//' | sed 's/\.//'`
        echo "http://llvm.org/svn/llvm-project/llvm/branches/release_$ver"
    fi
}

# Print url to clang Subversion repository
function get_clang_svn_url() {
    if [ "$clang_base" = "clang-trunk" ] ; then
        echo "http://llvm.org/svn/llvm-project/cfe/trunk"
    else
        local ver=`echo "$clang_base" | sed 's/clang-//' | sed 's/\.//'`
        echo "http://llvm.org/svn/llvm-project/cfe/branches/release_$ver"
    fi
}

# Override default packages versions using environment variables
function setup_packages_versions() {
    test -z "$LLVM_VER" || llvm_base="llvm-$LLVM_VER"
    test -z "$CLANG_VER" || clang_base="clang-$CLANG_VER"
}

# Unpack everything
function unpack_packages() {
    cd $src_dir
    tar vfxj ${dld_dir}/"${llvm_base}.tar.bz2" && \
    tar vfxj ${dld_dir}/"${clang_base}.tar.bz2" || \
    return 1

    shopt -s nullglob

    # Apply patches to llvm
    for pf in ${wdr}/patches/*.${llvm_base}.patch ; do
        echo "Apply patch: `basename $pf`"
        patch -p0 -d ${src_dir}/${llvm_base} < "$pf" || return 1
    done

    # Apply patches to clang
    for pf in ${wdr}/patches/*.${clang_base}.patch ; do
        echo "Apply patch: `basename $pf`"
        patch -p0 -d ${src_dir}/${clang_base} < "$pf" || return 1
    done

    test -e ${src_dir}/${llvm_base}/tools/clang || \
    ln -s ${src_dir}/${clang_base} ${src_dir}/${llvm_base}/tools/clang
}

# Build llvm/clang
function build_llvm_clang() {
    cd $bld_dir
    mkdir $llvm_base
    cd $llvm_base

    local opts=""
    local host_opt=""
    local target_opt=""
    local build_opt=""

    if [ "$is_debug" = "no" ] ; then
        opts="--enable-optimized"
    else
        opts="--disable-optimized"
    fi

    if [ ! -z "$host" ] ; then
        host_opt="--host=${host}"
    fi

    if [ ! -z "$target" ] ; then
        target_opt="--target=${target}"
    fi

    if [ ! -z "$build" ] ; then
        build_opt="--build=${build}"
    fi

    ${src_dir}/${llvm_base}/configure \
        --prefix=$prefix \
        ${opts} \
        ${host_opt} ${target_opt} ${build_opt} || \
    return 1

    make ${make_opts} && \
    make ${make_opts} install
}

# Run a set of simple smoke tests
function run_smoke_tests() {
    run_smoke_test "mips" "-g"
    run_smoke_test "mipsel" "-g"
}

# Run c/c++ smoke test
function run_smoke_test() {
    local arch="$1"
    local opts="$2"
    local arch_opts=""

    local tc_gcc=`which ${arch}-linux-gnu-gcc`
    local tc_bin=`dirname $tc_gcc`
    local tc_root=$tc_bin/..

    echo "%%% Check '$opts' on '$arch'"

    cd $bld_dir
    rm -rf tests && mkdir tests && cd tests

    case "$arch" in
        mips)
            arch_opts="-EB"
            ;;
        mipsel)
            arch_opts="-EL"
            ;;
        *)
            echo "Unknown arch name: $arch" 1>&2
            return 1
            ;;
    esac

cat > hello.c <<END_OF_HELLO_C
#include <stdio.h>

int main(int argc, const char *argv[])
{
    printf("Hello World!\n");
    return 0;
}
END_OF_HELLO_C

cat > hello.cxx <<END_OF_HELLO_CXX
#include <iostream>

int main(int argc, const char *argv[])
{
    std::cout << "Hello World!" << std::endl;
    return 0;
}
END_OF_HELLO_CXX

cat > commands <<END_OF_GDB_CMDS
target remote :1234
break main
step
step
step
kill
quit
y
END_OF_GDB_CMDS

    # Check C code
    ${prefix}/bin/clang \
        -ccc-host-triple ${arch}-unknown-linux -ccc-clang-archs ${arch} \
        -I${tc_root}/mips-linux-gnu/sysroot/usr/include \
        ${opts} -msoft-float -std=gnu89 -D_MIPS_SZPTR=32 -D_MIPS_SIM=_ABIO32 \
        -emit-llvm -O3 -S -g hello.c -o hello.ll && \
    ${prefix}/bin/llc -march=${arch} -mcpu=mips32r2 \
        -disable-phi-elim-edge-splitting hello.ll -o hello.s && \
    mips-linux-gnu-gcc -mips32r2 ${arch_opts} -O3 -fPIC \
        hello.s -o hello.o -c && \
    mips-linux-gnu-gcc -mips32r2 ${arch_opts} -O3 -fPIC -static \
        hello.o -ohello && \
    qemu-${arch} hello || return 1

    qemu-${arch} -g 1234 hello &
    mips-linux-gnu-gdb -q -x commands hello || return 1

    # Check C++ code
    ${prefix}/bin/clang++ \
        -ccc-host-triple ${arch}-unknown-linux -ccc-clang-archs ${arch} \
        -I${tc_root}/mips-linux-gnu/sysroot/usr/include \
        -D_MIPS_SZPTR=32 -D_MIPS_SIM=_ABIO32 -msoft-float -emit-llvm \
        ${opts} -O3 -S -g -ohelloxx hello.cxx -o hello.ll && \
    ${prefix}/bin/llc -march=${arch} -mcpu=mips32r2 \
        -disable-phi-elim-edge-splitting hello.ll -o hello.s && \
    mips-linux-gnu-g++ -mips32r2 ${arch_opts} -O3 -fPIC \
        hello.s -o hello.o -c && \
    mips-linux-gnu-g++ -mips32r2 -EL -O3 -fPIC -static \
        hello.o -ohelloxx && \
    qemu-${arch} helloxx || return 1

    qemu-${arch} -g 1234 helloxx &
    mips-linux-gnu-gdb -q -x commands helloxx || return 1
}

# Remove source, build and all aux directories
function cleanup() {
    rm -rf "$src_dir" "$bld_dir"
}

# Download missed packages
function download() {
    if [ ! -e "${dld_dir}/${llvm_base}.tar.bz2" ] ; then
        local tdir=`mktemp -d`

        svn export `get_llvm_svn_url` ${tdir}/${llvm_base} || \
        return 1

        tar -C ${tdir} -cjf ${dld_dir}/${llvm_base}.tar.bz2 ${llvm_base} && \
        rm -rf ${tdir}
    fi

    if [ ! -e "${dld_dir}/${clang_base}.tar.bz2" ] ; then
        local tdir=`mktemp -d`

        svn export `get_clang_svn_url` ${tdir}/${clang_base} || \
        return 1

        tar -C ${tdir} -cjf ${dld_dir}/${clang_base}.tar.bz2 ${clang_base} && \
        rm -rf ${tdir}
    fi
}

# Run commands
function run_commands() {
    declare -a cmds=("${!1}")

    all_cmds=("unpack" "buildclang" "check")

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
            buildclang)
                run_stage "build_llvm_clang" "Build llvm/clang"
                ;;
            check)
                run_stage "run_smoke_tests" "Test llvm/clang"
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
    setup_packages_versions
fi

run_commands cmds[@]
