#!/bin/bash -x

if [ -z $1 ]; then
    DO=gcc
else
    DO=$1
fi

if [ -z $2 ]; then
    TOOLCHAIN=/projects/mipssw/toolchains/nanomips-linux-musl/2019.03-01
else
    TOOLCHAIN=$2
fi

if [ ! -d $TOOLCHAIN ]; then
    echo "ERROR: Toolchain directory not found $TOOLCHAIN"
    exit 1
fi

if [ -n $3 ]; then
    SRCDIR=$3
fi

if [ ! -d $SRCDIR ]; then
    echo "ERROR: Source directory not found $SRCDIR"
    exit 1
fi

if [ ! -d $SRCDIR/dejagnu ]; then
    echo "ERROR: DejaGNU source not found $SRCDIR/dejagnu"
    exit 1
fi

if [ ! -d $SRCDIR/gcc ]; then
    echo "ERROR: GCC source not found $SRCDIR/gcc"
    exit 1
fi

HOSTTOOLS=${HOSTTOOLSROOT:-/projects/mipssw/toolchains/}x86_64-pc-linux-gnu/4.9.4-centos6/

declare -a configs
configs=(
    "multi-sim/-m32/-EL/-msoft-float" 
    "multi-sim/-m32/-EL/-msoft-float/-fpic" 
    "multi-sim/-m32/-EL/-msoft-float/-mcmodel=medium/-fpic" 
    "multi-sim/-m32/-EL/-msoft-float/-mcmodel=large/-fPIC"
)
jobs=""

if [ $DO = "gcc" -o $DO = "both" -o $DO = "all" ]; then
for cfg in "${configs[@]}"; do
    name="gcc_"`echo ${cfg#*/} | tr -d - | tr -d =  | tr / _`
    mkdir $name
    pushd $name
    rm -Rf *
    PATH=$TOOLCHAIN/bin:$HOSTTOOLS/bin:$SRCDIR/dejagnu:$PATH HOSTCC=x86_64-pc-linux-gnu-gcc DEJAGNU_SIM_OPTIONS="-r 4.5.0 -cpu nanomips-generic"  DEJAGNU_SIM=$TOOLCHAIN/bin/qemu-nanomips DEJAGNU_SIM_GCC=$TOOLCHAIN/bin/nanomips-linux-musl-gcc $SRCDIR/gcc/contrib/test_installed --without-gfortran --without-objc --without-g++ --with-gcc=$TOOLCHAIN/bin/nanomips-linux-musl-gcc --prefix=$TOOLCHAIN --target=nanomips-linux-musl --target_board=$cfg -v -v -v &> test.log &
    popd
done
fi

if [ $DO = "g++" -o $DO = "both" -o $DO = "all" ]; then
for cfg in "${configs[@]}"; do
    name="gxx_"`echo ${cfg#*/} | tr -d - | tr -d =  | tr / _`
    
    mkdir $name
    pushd $name
    rm -Rf *

    PATH=$TOOLCHAIN/bin:$HOSTTOOLS/bin:$SRCDIR/dejagnu:$PATH HOSTCC=x86_64-pc-linux-gnu-gcc DEJAGNU_SIM_OPTIONS="-r 4.5.0 -cpu nanomips-generic" DEJAGNU_SIM=$TOOLCHAIN/bin/qemu-nanomips DEJAGNU_SIM_GCC=$TOOLCHAIN/bin/nanomips-linux-musl-gcc $SRCDIR/gcc/contrib/test_installed --without-gfortran --without-objc --without-gcc --with-g++=$TOOLCHAIN/bin/nanomips-linux-musl-g++ --prefix=$TOOLCHAIN --target=nanomips-linux-musl --target_board=$cfg -v -v -v &> test.log &
    popd
done
fi

wait
