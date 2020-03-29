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

# manipulate the test_installed script to generate a modified site.exp
sed 's|^set CFLAGS.*$|set CFLAGS \"\"\nset HOSTCC \"gcc\"\nset HOSTCFLAGS \"\"|' $SRCDIR/gcc/contrib/test_installed > $SRCDIR/gcc/contrib/test_installed.gcc"$$"
chmod +x $SRCDIR/gcc/contrib/test_installed.gcc"$$"

if [ $DO = "gcc" -o $DO = "both" -o $DO = "all" ]; then
for cfg in "${configs[@]}"; do
    name="gcc_"`echo ${cfg#*/} | tr -d - | tr -d =  | tr / _`
    mkdir $name
    pushd $name
    rm -Rf *
    PATH=$TOOLCHAIN/bin:$HOSTTOOLS/bin:$SRCDIR/dejagnu:$PATH HOSTCC=x86_64-pc-linux-gnu-gcc DEJAGNU_SIM_OPTIONS="-r 4.5.0 -cpu nanomips-generic"  DEJAGNU_SIM=$TOOLCHAIN/bin/qemu-nanomips DEJAGNU_SIM_GCC=$TOOLCHAIN/bin/nanomips-linux-musl-gcc $SRCDIR/gcc/contrib/test_installed.gcc"$$" --without-gfortran --without-objc --without-g++ --with-gcc=$TOOLCHAIN/bin/nanomips-linux-musl-gcc --prefix=$TOOLCHAIN --target=nanomips-linux-musl --target_board=$cfg -v -v -v &> test.log &
    popd
done
fi

# manipulate the test_installed script to generate a modified site.exp
sed 's|^set GCC_UNDER_TEST.*$|set GCC_UNDER_TEST \"${target+$target-}gcc\"\nset HOSTCC \"gcc\"\nset HOSTCLFAGS \"\"|' $SRCDIR/gcc/contrib/test_installed > $SRCDIR/gcc/contrib/test_installed.g++"$$"
chmod +x $SRCDIR/gcc/contrib/test_installed.g++"$$"

if [ $DO = "g++" -o $DO = "both" -o $DO = "all" ]; then
for cfg in "${configs[@]}"; do
    name="gxx_"`echo ${cfg#*/} | tr -d - | tr -d =  | tr / _`
    
    mkdir $name
    pushd $name
    rm -Rf *

    PATH=$TOOLCHAIN/bin:$HOSTTOOLS/bin:$SRCDIR/dejagnu:$PATH HOSTCC=x86_64-pc-linux-gnu-gcc DEJAGNU_SIM_OPTIONS="-r 4.5.0 -cpu nanomips-generic" DEJAGNU_SIM=$TOOLCHAIN/bin/qemu-nanomips DEJAGNU_SIM_GCC=$TOOLCHAIN/bin/nanomips-linux-musl-gcc $SRCDIR/gcc/contrib/test_installed.g++"$$" --without-gfortran --without-objc --without-gcc --with-g++=$TOOLCHAIN/bin/nanomips-linux-musl-g++ --prefix=$TOOLCHAIN --target=nanomips-linux-musl --target_board=$cfg -v -v -v &> test.log &
    popd
done
fi

wait
# cleanup
rm -f $SRCDIR/gcc/contrib/test_installed.gcc"$$" $SRCDIR/gcc/contrib/test_installed.g++"$$"
