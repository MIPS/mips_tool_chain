#!/bin/bash -x

if [ -z $1 ]; then
    DO=gcc
else
    DO=$1
fi

if [ -z $2 ]; then
    TOOLCHAIN=/projects/mipssw/toolchains/nanomips-elf/2019.03-01
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

HOSTTOOLS=${HOSTTOOLSROOT:-/projects/mipssw/toolchains/}x86_64-pc-linux-gnu/4.9.4-centos6

declare -a configs
configs=(
    "generic-sim/-m32/-EL/-msoft-float"
    "generic-sim/-m32/-EL/-msoft-float/-mcmodel=medium"
    "generic-sim/-m32/-EL/-msoft-float/-mcmodel=large"
    "generic-sim/-m32/-EL/-msoft-float/-mpid"
    "generic-sim/-m32/-EL/-msoft-float/-mcmodel=medium/-mpid"
    "generic-sim/-m32/-EL/-msoft-float/-mcmodel=large/-mpid"
    "generic-sim/-m32/-EL/-msoft-float/-mno-gpopt"
    "generic-sim/-m32/-EL/-msoft-float/-mcmodel=medium/-mno-gpopt"
    "generic-sim/-m32/-EL/-msoft-float/-mcmodel=large/-mno-gpopt"
    "generic-sim/-m32/-EL/-msoft-float/-mno-gpopt/-mno-pcrel"
    "generic-sim/-m32/-EL/-msoft-float/-mcmodel=medium/-mno-gpopt/-mno-pcrel"
    "generic-sim/-m32/-EL/-msoft-float/-mcmodel=large/-mno-gpopt/-mno-pcrel")
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
    DEJAGNU_SIM_LDSCRIPT="-Tuhi32.ld" DEJAGNU_SIM_LINK_FLAGS="-Wl,--defsym,__memory_size=32M" DEJAGNU_SIM_OPTIONS="-cpu nanomips-generic -semihosting -nographic -kernel"  DEJAGNU_SIM=$TOOLCHAIN/bin/qemu-system-nanomips PATH=$TOOLCHAIN/bin:$HOSTTOOLS/bin:$SRCDIR/dejagnu:$PATH $SRCDIR/gcc/contrib/test_installed.gcc"$$" --without-gfortran --without-objc --without-g++ --with-gcc=$TOOLCHAIN/bin/nanomips-elf-gcc --prefix=$TOOLCHAIN --target=nanomips-elf --target_board=$cfg -v -v -v $4 &> test.log &
    popd
done
fi

# manipulate the test_installed script to generate a modified site.exp
sed 's|^set GCC_UNDER_TEST.*$|set GCC_UNDER_TEST \"'$TOOLCHAIN'/bin/nanomips-elf-gcc\"\nset HOSTCC \"gcc\"\nset HOSTCFLAGS \"\"|' $SRCDIR/gcc/contrib/test_installed > $SRCDIR/gcc/contrib/test_installed.g++"$$"
chmod +x $SRCDIR/gcc/contrib/test_installed.g++"$$"

if [ $DO = "g++" -o $DO = "both" -o $DO = "all" ]; then
for cfg in "${configs[@]}"; do
    name="gxx_"`echo ${cfg#*/} | tr -d - | tr -d =  | tr / _`

    mkdir $name
    pushd $name
    rm -Rf *

    DEJAGNU_SIM_LDSCRIPT="-Tuhi32.ld" DEJAGNU_SIM_LINK_FLAGS="-Wl,--defsym,__memory_size=32M" DEJAGNU_SIM_OPTIONS="-cpu nanomips-generic -semihosting -nographic -kernel"  DEJAGNU_SIM=$TOOLCHAIN/bin/qemu-system-nanomips PATH=$TOOLCHAIN/bin:$HOSTTOOLS/bin:$SRCDIR/dejagnu:$PATH $SRCDIR/gcc/contrib/test_installed.g++"$$" --without-gfortran --without-objc --without-gcc --with-g++=$TOOLCHAIN/bin/nanomips-elf-g++ --prefix=$TOOLCHAIN --target=nanomips-elf --target_board=$cfg -v -v -v  $4 &> test.log &
   popd
done

fi

wait
# cleanup
rm -f $SRCDIR/gcc/contrib/test_installed.gcc"$$" $SRCDIR/gcc/contrib/test_installed.g++"$$"
