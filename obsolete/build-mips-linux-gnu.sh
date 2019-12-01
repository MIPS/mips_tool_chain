#!/bin/bash
#
# This script builds toolchain for mips-linux-gnu target.
# Version 1.3
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
linux_base=linux-2.6.32.27
eglibc_base=eglibc-2_14
expat_base=expat-2.0.1
gdb_base=gdb-7.2
qemu_base=qemu-1.0.1

# Script name and path
prg=`basename "$0"`
wdr=$(readlink -f `dirname "$0"`)

# Initialize script settings by default values
cmds=("buildall")
prefix="$PREFIX"
dld_dir="$PWD"/dl
src_dir="$PWD"/src
bld_dir="$PWD"/bld
int_inst_dir="$PWD"/install
make_opts=""

# Setup arch and target names
arch="mips"

# Print script usage info
function usage() {
    echo "Usage: $prg [OPTIONS] COMMANDS"
    echo ""
    echo "COMMANDS"
    echo "    buildall            run all building stages from unpack to check"
    echo "    download            check packages and download missed ones"
    echo "    cleanup             remove source, build and aux dirs"
    echo "    package             create binary and source packages"
    echo "    help                print this help message"
    echo ""
    echo "    unpack              unpack packages"
    echo "    buildgmp            build GMP library"
    echo "    buildmpfr           build MPFR library"
    echo "    buildmpc            build MPC library"
    echo "    buildbinutils       build Binutils"
    echo "    buildgcc1           build GCC phase I"
    echo "    installheaders      install Linux headers"
    echo "    buildeglibc1        build eglibc headers and preliminary objects"
    echo "    buildgcc2           build GCC phase II"
    echo "    buildeglibc2        build eglibc libraries"
    echo "    buildgcc3           build GCC phase III"
    echo "    buildlibgcc         build libgcc"
    echo "    buildexpat          build expat"
    echo "    buildgdb            build GDB"
    echo "    buildqemu           build QEMU"
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
    echo "    -j, --jobs=NUM      run NUM make jobs simultaneously"
    echo ""
    echo "ENVIRONMENT"
    echo "    You can override default packages versions using the following"
    echo "    environment variables. For example 'GMP_VER=5.5.5 $prg'."
    echo "    GMP_VER             gmp library version"
    echo "    MPC_VER             mpc library version"
    echo "    MPFR_VER            mpfr library version"
    echo "    BINUTILS_VER        binutils version"
    echo "    GCC_VER             gcc version"
    echo "    LINUX_VER           linux kernel"
    echo "    EGLIBC_VER          eglibc library version"
    echo "    EXPAT_VER           expat library version"
    echo "    GDB_VER             gdb version"
    echo "    QEMU_VER            qemu version"
}

# Parse command line arguments
function parse_args() {
    local opts=`getopt -n "$prg" \
             --long help,arch:,prefix:,download:,source:,build:,jobs: \
             -o ha:p:d:s:b:j: \
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

# Print major.minor version of linux kernel
function get_linux_major_minor_ver() {
    echo "$linux_base" | \
        sed 's/^linux-\([0-9]\)\.\([0-9]\)\.\(.*\)/\1\.\2/'
}

# Print full version of linux kernel
function get_linux_full_ver() {
    echo "$linux_base" | sed 's/linux-//'
}

# Override default packages versions using environment variables
function setup_packages_versions() {
    test -z "$GMP_VER" || gmp_base="gmp-$GMP_VER"
    test -z "$MPC_VER" || mpc_base="mpc-$MPC_VER"
    test -z "$MPFR_VER" || mpfr_base="mpfr-$MPFR_VER"
    test -z "$BINUTILS_VER" || binutils_base="binutils-$BINUTILS_VER"
    test -z "$GCC_VER" || gcc_base="gcc-$GCC_VER"
    test -z "$LINUX_VER" || linux_base="linux-$LINUX_VER"
    test -z "$EGLIBC_VER" || eglibc_base="eglibc-$EGLIBC_VER"
    test -z "$EXPAT_VER" || expat_base="expat-$EXPAT_VER"
    test -z "$GDB_VER" || gdb_base="gdb-$GDB_VER"
    test -z "$QEMU_VER" || qemu_base="qemu-$QEMU_VER"
}

# Unpack everything
function unpack_packages() {
    cd $src_dir
    tar vfxj ${dld_dir}/"${gmp_base}.tar.bz2" && \
    tar vfxj ${dld_dir}/"${mpfr_base}.tar.bz2" && \
    tar vfxz ${dld_dir}/"${mpc_base}.tar.gz" && \
    tar vfxj ${dld_dir}/"${binutils_base}.tar.bz2" && \
    tar vfxj ${dld_dir}/"${gcc_base}.tar.bz2" && \
    tar vfxj ${dld_dir}/"${linux_base}.tar.bz2" && \
    tar vfxj ${dld_dir}/"${eglibc_base}.tar.bz2" && \
    tar vfxz ${dld_dir}/"${expat_base}.tar.gz" && \
    tar vfxj ${dld_dir}/"${gdb_base}.tar.bz2" && \
    tar vfxz ${dld_dir}/"${qemu_base}.tar.gz" || \
    return 1

    # Apply patches to gcc
    for pf in ${wdr}/patches/*.${gcc_base}.patch ; do
        echo "Apply patch: `basename $pf`"
        patch -p1 -d ${src_dir}/${gcc_base} < "$pf" || return 1
    done
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
        --target=$target \
        --with-sysroot=$sysroot && \
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
        --enable-languages=c \
        --with-arch=mips32r2 \
        --with-newlib --without-headers \
        --disable-shared --disable-threads \
        --disable-libssp --disable-libgomp --disable-libmudflap \
        --disable-fixed-point --disable-decimal-float && \
    make ${make_opts} && \
    make ${make_opts} install
}

# Install linux headers
function install_linux_headers() {
    cd ${src_dir}/${linux_base}
    make ${make_opts} headers_install \
        ARCH=mips CROSS_COMPILE=$target- INSTALL_HDR_PATH=$sysroot/usr 
}

# Build eglibc headers and preliminary objects
function build_eglibc_p1() {
    local kernel_ver=`get_linux_full_ver`

    cd $src_dir/${eglibc_base}/libc
    ln -s ../ports ports

    cd $bld_dir
    mkdir ${eglibc_base}-headers
    cd ${eglibc_base}-headers

    endian=("" "-EL" "-msoft-float" "-EL -msoft-float" "-mips32" \
            "-EL -mips32" "-msoft-float -mips32" "-EL -msoft-float -mips32")
    sysroot_ext=("/" "/el/" "/soft-float/" "/el/soft-float/" "/mips32/" \
                 "/el/mips32/" "/soft-float/mips32/" "/el/soft-float/mips32/")

    for (( i=0; i < 8; i++ )) ; do
        export BUILD_CC=gcc
        export CC="$prefix/bin/$target-gcc ${endian[i]}"
        export CXX="$prefix/bin/$target-g++ ${endian[i]}"
        export AR=$prefix/bin/$target-ar
        export RANLIB=$prefix/bin/$target-ranlib

        ${src_dir}/${eglibc_base}/libc/configure --prefix=/usr \
            --with-headers=$sysroot/usr/include --build=i686-pc-linux-gnu \
            --host=$target --disable-profile --without-gd --without-cvs \
            --enable-add-ons --enable-kernel=$kernel_ver || \
        return 1

        make ${make_opts} install-headers \
            install_root=$sysroot${sysroot_ext[i]} \
            install-bootstrap-headers=yes || \
        return 1

        mkdir -p $sysroot${sysroot_ext[i]}usr/lib
        make ${make_opts} csu/subdir_lib && \
        cp csu/crt1.o csu/crti.o csu/crtn.o \
           $sysroot${sysroot_ext[i]}usr/lib && \
        $CC -nostdlib -nostartfiles -shared -x c /dev/null \
            -o $sysroot${sysroot_ext[i]}usr/lib/libc.so ||
        return 1
    done

    unset BUILD_CC
    unset CC
    unset CXX
    unset AR
    unset RANLIB
}

# Build GCC phase 2
function build_gcc_p2() {
    cd $bld_dir
    mkdir ${gcc_base}-intermediate
    cd ${gcc_base}-intermediate
    ${src_dir}/${gcc_base}/configure \
        --prefix=$prefix \
        --target=$target \
        --with-sysroot=$sysroot \
        --with-gmp=${int_inst_dir}/${gmp_base} \
        --with-mpfr=${int_inst_dir}/${mpfr_base} \
        --with-mpc=${int_inst_dir}/${mpc_base} \
        --enable-languages=c \
        --with-arch=mips32r2 \
        --disable-libssp --disable-libgomp --disable-libmudflap \
        --disable-fixed-point --disable-decimal-float && \
    make ${make_opts} && \
    make ${make_opts} install
}

# Build eglibc
function build_eglibc_p2() {
    local kernel_ver=`get_linux_full_ver`

    cd $bld_dir
    mkdir ${eglibc_base}
    cd ${eglibc_base}

    endian=("" "-mips32" "-EL" "-msoft-float" "-mips32 -EL" \
            "-mips32 -msoft-float" "-EL -msoft-float" \
            "-mips32 -EL -msoft-float")
    sysroot_ext=("/" "/mips32/" "/el/" "/soft-float/" "/el/mips32/" \
                 "/soft-float/mips32/" "/el/soft-float/" \
                 "/el/soft-float/mips32/")
    fp=("" "" "" "--without-fp" "" "--without-fp" "--without-fp" "--without-fp")

    for (( i=0; i < 8; i++ )) ; do
        export BUILD_CC=gcc
        export CC="$prefix/bin/$target-gcc ${endian[i]}"
        export CXX="$prefix/bin/$target-g++ ${endian[i]}"
        export AR=$prefix/bin/$target-ar
        export RANLIB=$prefix/bin/$target-ranlib

        if [ -f Makefile ] ; then
            make ${make_opts} clean || return 1
        fi
        rm -fr catgets/xmalloc.o sunrpc/*

        ${src_dir}/${eglibc_base}/libc/configure --prefix=/usr \
            --with-headers=$sysroot/usr/include --build=i686-pc-linux-gnu \
            --host=$target --disable-profile --without-gd --without-cvs \
            --enable-add-ons --enable-kernel=$kernel_ver ${fp[i]} || \
        return 1

        make ${make_opts} && \
        make ${make_opts} install install_root=$sysroot${sysroot_ext[i]} || \
        return 1
    done

    unset BUILD_CC
    unset CC
    unset CXX
    unset AR
    unset RANLIB
}

# Build GCC phase 3
function build_gcc_p3() {
    cd $bld_dir
    mkdir ${gcc_base}-final
    cd ${gcc_base}-final
    ${src_dir}/${gcc_base}/configure \
        --prefix=$prefix \
        --target=$target \
        --with-sysroot=$sysroot \
        --enable-__cxa_atexit \
        --with-gmp=${int_inst_dir}/${gmp_base} \
        --with-mpfr=${int_inst_dir}/${mpfr_base} \
        --with-mpc=${int_inst_dir}/${mpc_base} \
        --enable-languages=c,c++ \
        --with-arch=mips32r2 --with-llsc --with-synci --with-mips-plt \
        --disable-libssp --disable-libgomp --disable-libmudflap \
        --disable-fixed-point --disable-decimal-float && \
    make ${make_opts} && \
    make ${make_opts} install
}

# Copy libgcc
function build_libgcc() {
    cd ${gcc_base}-final
    make ${make_opts} all-target-libgcc && \
    make ${make_opts} install-target-libgcc || \
    return 1

    cd $prefix/$target/lib
    cp libgcc* $sysroot/lib/ && \
    cp soft-float/libgcc* $sysroot/soft-float/lib/ && \
    cp mips32/libgcc* $sysroot/mips32/lib/ && \
    cp soft-float/mips32/libgcc* $sysroot/soft-float/mips32/lib/ || \
    return 1

    cp el/libgcc* $sysroot/el/lib/ && \
    cp el/soft-float/libgcc* $sysroot/el/soft-float/lib/ && \
    cp el/mips32/libgcc* $sysroot/el/mips32/lib/ && \
    cp el/soft-float/mips32/libgcc* $sysroot/el/soft-float/mips32/lib/ || \
    return 1
}

# Build expat
function build_expat() {
    cd $bld_dir
    mkdir ${expat_base}
    cd ${expat_base}
    ${src_dir}/${expat_base}/configure \
        --prefix=${int_inst_dir}/${expat_base} \
        --disable-shared && \
    make ${make_opts} && \
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
        --with-expat-prefix=${int_inst_dir}/${expat_base} && \
    make ${make_opts} && \
    make ${make_opts} install
}

# Build qemu
function build_qemu() {
    cd $bld_dir
    mkdir ${qemu_base}
    cd ${qemu_base}
    ${src_dir}/${qemu_base}/configure \
        --prefix=$prefix \
        --interp-prefix=${sysroot} \
        --target-list="mips-linux-user,mipsel-linux-user,mips-softmmu,mipsel-softmmu,mips64-softmmu,mips64el-softmmu" \
        --extra-cflags='-DMIPS_AVP -DMIPS_STRICT_STANDARD' && \
    make ${make_opts} && \
    make ${make_opts} install
}

# Run a set of simple smoke tests
function run_smoke_tests() {
    local opts=("" "-mips32" "-msoft-float" "-mips32 -msoft-float")

    for opt in "${opts[@]}" ; do
        run_smoke_test "mips" "-g $opt"
        run_smoke_test "mipsel" "-g $opt"
    done
}

# Run c/c++ smoke test
function run_smoke_test() {
    local test_arch="$1"
    local opts="$2"

    echo "%%% Check '$opts' on '$test_arch'"

    cd $bld_dir
    rm -rf tests && mkdir tests && cd tests

    case "$test_arch" in
        mips)
            opts="-EB $opts"
            ;;
        mipsel)
            opts="-EL $opts"
            ;;
        *)
            echo "Unknown arch name: $test_arch" 1>&2
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
    ${prefix}/bin/mips-linux-gnu-gcc $opts hello.c -o hello -static && \
    ${prefix}/bin/qemu-${test_arch} ./hello || return 1
    ${prefix}/bin/qemu-${test_arch} -g 1234 hello &
    ${prefix}/bin/mips-linux-gnu-gdb -q -x commands hello || return 1

    # Check C++ code
    ${prefix}/bin/mips-linux-gnu-g++ $opts hello.cxx -o helloxx -static && \
    ${prefix}/bin/qemu-${test_arch} ./helloxx || return 1
    ${prefix}/bin/qemu-${test_arch} -g 1234 helloxx &
    ${prefix}/bin/mips-linux-gnu-gdb -q -x commands helloxx || return 1
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

    if [ ! -e "${dld_dir}/${linux_base}.tar.bz2" ] ; then
        local ver=`get_linux_major_minor_ver`

        wget ${wget_opts} -O "${dld_dir}/${linux_base}.tar.bz2" \
            http://www.kernel.org/pub/linux/kernel/v${ver}/${linux_base}.tar.bz2 || \
        return 1
    fi

    if [ ! -e "${dld_dir}/${gcc_base}.tar.bz2" ] ; then
        wget ${wget_opts} -O "${dld_dir}/${gcc_base}.tar.bz2" \
            ftp://ftp.gnu.org/gnu/gcc/${gcc_base}/${gcc_base}.tar.bz2 || \
        return 1
    fi

    if [ ! -e "${dld_dir}/${eglibc_base}.tar.bz2" ] ; then
        local tdir=`mktemp -d`

        svn export http://www.eglibc.org/svn/branches/${eglibc_base}/ \
            ${tdir}/${eglibc_base} || \
        return 1

        tar -C ${tdir} -cjf ${dld_dir}/${eglibc_base}.tar.bz2 ${eglibc_base} && \
        rm -rf ${tdir}
    fi

    if [ ! -e "${dld_dir}/${expat_base}.tar.gz" ] ; then
        local ver=`echo "$expat_base" | sed 's/expat-\([0-9\.]\)/\1/'`

        wget ${wget_opts} -O "${dld_dir}/${expat_base}.tar.gz" --trust-server-names \
            http://sourceforge.net/projects/expat/files/expat/${ver}/expat-${ver}.tar.gz/download || \
        return 1
    fi

    if [ ! -e "${dld_dir}/${gdb_base}.tar.bz2" ] ; then
        wget ${wget_opts} -O "${dld_dir}/${gdb_base}.tar.bz2" \
            http://ftp.gnu.org/gnu/gdb/${gdb_base}a.tar.bz2 || \
        return 1
    fi

    if [ ! -e "${dld_dir}/${qemu_base}.tar.gz" ] ; then
        wget ${wget_opts} -O "${dld_dir}/${qemu_base}.tar.gz" \
            http://wiki.qemu.org/download/${qemu_base}.tar.gz || \
        return 1
    fi
}

# Get the script version
function get_version() {
    sed -n 's/# Version \([0-9]*\.[0-9]*\)/\1/p' < ${wdr}/${prg}
}

# Create binary and source packages
function create_packages() {
    local prefix_dir=`dirname ${prefix}`
    local prefix_name=`basename ${prefix}`
    local src_pkg_dir="/tmp/mips_linux_toolchain_src"
    local ver=`get_version`

    # Binary package
cat > ${prefix}/README <<END_OF_BIN_README
This package contains a binary Linux toolchain for MIPS. This is referred
to as target mips-linux-gnu. The C library is from egibc.

Components
-----------------------------
The toolchain consists of a number of components. The current version
is built with the following:
${binutils_base} http://www.gnu.org/software/binutils/
${eglibc_base}     http://www.eglibc.org/
${expat_base}     http://expat.sourceforge.net/
${gcc_base}       http://gcc.gnu.org/
${gdb_base}         http://www.gnu.org/software/gdb/
${gmp_base}       http://gmplib.org/
${linux_base} http://kernel.org/
${mpc_base}         http://www.multiprecision.org/
${mpfr_base}      http://www.mpfr.org/
${qemu_base}     http://wiki.qemu.org/Main_Page

Quick Start
-----------------------------
1. Unpack the tarball to the /opt folder.
2. Add the /opt/mips-linux-toolchan/bin folder to the path.
END_OF_BIN_README

    tar -C ${prefix_dir} \
        -cvjf Mips_linux_toolchain_bin-${ver}.${gcc_base}.tar.bz2 \
        ${prefix_name} || return 1

    # Source package
    rm -rf ${src_pkg_dir} && mkdir ${src_pkg_dir} || return 1

    ln -s ${dld_dir} ${src_pkg_dir}/dl
    ln -s ${wdr}/${prg} ${src_pkg_dir}
    ln -s ${wdr}/patches ${src_pkg_dir}

cat > ${src_pkg_dir}/README <<END_OF_SRC_README
This package contains tarballs, patches and command file, with which you
can build your own custom toolchain for MIPS.

Components
-----------------------------
The toolchain consists of a number of components. The current version
is built with the following:
${binutils_base} http://www.gnu.org/software/binutils/
${eglibc_base}     http://www.eglibc.org/
${expat_base}     http://expat.sourceforge.net/
${gcc_base}       http://gcc.gnu.org/
${gdb_base}         http://www.gnu.org/software/gdb/
${gmp_base}       http://gmplib.org/
${linux_base} http://kernel.org/
${mpc_base}         http://www.multiprecision.org/
${mpfr_base}      http://www.mpfr.org/
${qemu_base}     http://wiki.qemu.org/Main_Page

Mandatory external components
-----------------------------
Various components must be installed on your computer before proceeding,
if they are not already there. http://gcc.gnu.org/install/prerequisites.html.
In general you will receive the proper warning if you are missing some
component but not always so it's good to read through the list.
1. gcc/g++
2. make and patch tools
3. Development verions of ncurses, zlib and glib2

Quick Start
-----------------------------
To get a full list of build options run the build script with
the help command:
./build-mips-linux-gnu.sh help.

1. Unpack the tarball
2. Run the build script (DIR is a folder where you want to install
the toolchain):
./build-mips-linux-gnu.sh --prefix=DIR
END_OF_SRC_README

    tar -C `dirname ${src_pkg_dir}` \
        --dereference --exclude=.git \
        -cvjf Mips_linux_toolchain_src-${ver}.${gcc_base}.tar.bz2 \
        `basename ${src_pkg_dir}` || return 1
}

# Run commands
function run_commands() {
    declare -a cmds=("${!1}")

    all_cmds=("unpack" "buildgmp" "buildmpfr" "buildmpc"
              "buildbinutils" "buildgcc1" "installheaders"
              "buildeglibc1" "buildgcc2" "buildeglibc2"
              "buildgcc3" "buildlibgcc" "buildexpat"
              "buildgdb" "buildqemu" "check")

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
            installheaders)
                run_stage "install_linux_headers" "Install Linux hedaers"
                ;;
            buildeglibc1)
                run_stage "build_eglibc_p1" \
                          "Build eglibc headers and preliminary objects"
                ;;
            buildgcc2)
                run_stage "build_gcc_p2" "Build GCC phase II"
                ;;
            buildeglibc2)
                run_stage "build_eglibc_p2" "Build eglibc libraries"
                ;;
            buildgcc3)
                run_stage "build_gcc_p3" "Build GCC phase III"
                ;;
            buildlibgcc)
                run_stage "build_libgcc" "Build libgcc"
                ;;
            buildexpat)
                run_stage "build_expat" "Build expat"
                ;;
            buildgdb)
                run_stage "build_gdb" "Build GDB"
                ;;
            buildqemu)
                run_stage "build_qemu" "Build QEMU"
                ;;
            check)
                run_stage "run_smoke_tests" "Test toolchain"
                ;;
            package)
                run_stage "create_packages" "Create binary and source packages"
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
    sysroot="$prefix/$target/sysroot"
    target="${arch}-linux-gnu"
    mkdir -p $sysroot

    setup_packages_versions
fi

run_commands cmds[@]
