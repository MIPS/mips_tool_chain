#!/bin/bash -x

OPTS=`getopt -o s:r:c:a:j:h --long src:,runlist:,conf:,extra_args:,jobs:,help -n 'parse options' -- "$@"`
eval set -- "$OPTS"

dry_run=0
SRCDIR=""
RUNLIST=gcc,g\+\+
EXTRA_ARGS=""
TOOLCHAIN=""
CONFIG="mti,img"

while true ; do
    case $1 in
	-s|--src) SRCDIR=$2; shift 2;;
	-r|--runlist) RUNLIST=$2; shift 2;;
	-c|--conf) CONFIG=$2; shift 2;;
	-a|--extra_args) EXTRA_ARGS=\/${2/,/\/}; shift 2;;
	-j|--jobs) JOB_MAX=$2; shift 2;;
	-h|--help)
	    echo "$0 <opts,...> <toolchain_path>"
	    echo "Options:"
	    echo "	--src=<path_to_checked_out_sources>"
	    echo "	--runlist=gcc,g++"
	    echo "	--conf=mti/img"
	    echo "	--extra_args=<extra_cflags_for_test>"
	    echo "	--jobs=<max number of parallel test runs>"
	    echo "	--help		Print this message"
	    shift; exit; break;;
	--) TOOLCHAIN=$2; break;;
	*)  echo "Unrecognized option, try $0 --help";
	    exit 1
	    break;;
    esac
done

if [ -z $SRCDIR ]; then
    if [ -d src/gcc -a -d src/dejagnu ]; then
	SRCDIR=src
    else
	echo "ERROR: Need source directory for gcc/dejangu. Specify --src=<path_to_checked_out_sources>"
	exit 1
    fi
elif [ ! -d $SRCDIR ]; then
    echo "ERROR: No such directory: $SRCDIR"
    exit 1
fi

if [[ ! $RUNLIST =~ (gcc|g\+\+)(,(gcc|g\+\+))? ]]; then
    echo "error: must specify test to run: gcc,g++"
    exit 1
fi

if [ $CONFIG != mti -a $CONFIG != img ]; then
    echo "error: must specify configs to test: mti,img"
    exit 1
else
    TRIPLET="mips-$CONFIG-elf"
fi

if [ "x$TOOLCHAIN" == "x" ]; then
    echo "error: must specify toolchain root"
    exit 1
elif [ ! -d $TOOLCHAIN -o ! -d $TOOLCHAIN/bin -o ! -d $TOOLCHAIN/$TRIPLET/bin ]; then
    echo "error: toolchain root not found: $TOOLCHAIN"
fi

if [ ! -d $SRCDIR/gcc ]; then
    echo "error: expect gcc sources in $SRCDIR/gcc"
    exit 1
fi

if [ ! -d $SRCDIR/dejagnu ]; then
    echo "error: expect dejagnu sources in $SRCDIR/dejagnu"
    exit 1
fi

if [ -z $JOB_MAX ]; then
    which lscpu > /dev/null
    if [ $? -eq 0 ]; then
	JOB_MAX=`lscpu | grep -e ^CPU\(s\): | awk '{print $2;}'`
    else
	JOB_MAX=8 # assumed
    fi
fi

declare -a test_configs
declare -a img_configs
declare -a mti_configs

img_configs=(
    "generic-sim/-mips64r6/-mabi=64/-EL/-march=p6600"
    "generic-sim/-mips64r6/-mabi=64/-EL/-march=i6400"
    "generic-sim/-mips64r6/-mabi=64/-EL/-mhard-float"
    "generic-sim/-mips64r6/-mabi=64/-EL/-msoft-float"
    "generic-sim/-mips64r6/-mabi=64/-EB/-mhard-float"
    "generic-sim/-mips64r6/-mabi=64/-EB/-msoft-float"
    "generic-sim/-mips64r6/-mabi=n32/-EL/-mhard-float"
    "generic-sim/-mips64r6/-mabi=n32/-EL/-msoft-float"
    "generic-sim/-mips64r6/-mabi=n32/-EB/-mhard-float"
    "generic-sim/-mips64r6/-mabi=n32/-EB/-msoft-float"
    "generic-sim/-mips32r6/-mabi=32/-EL/-march=m6201/-mmicromips"
    "generic-sim/-mips32r6/-mabi=32/-EL/-march=m6201"
    "generic-sim/-mips32r6/-mabi=32/-EL/-mhard-float/-msingle-float/-fshort-double"
    "generic-sim/-mips32r6/-mabi=32/-EL/-mhard-float"
    "generic-sim/-mips32r6/-mabi=32/-EL/-msoft-float"
    "generic-sim/-mips32r6/-mabi=32/-EL/-mhard-float/-mmicromips"
    "generic-sim/-mips32r6/-mabi=32/-EL/-msoft-float/-mmicromips"
    "generic-sim/-mips32r6/-mabi=32/-EB/-mhard-float"
    "generic-sim/-mips32r6/-mabi=32/-EB/-msoft-float"
    "generic-sim/-mips32r6/-mabi=32/-EB/-mhard-float/-mmicromips"
    "generic-sim/-mips32r6/-mabi=32/-EB/-msoft-float/-mmicromips"
)

mti_configs=(
    "generic-sim/-mabi=64/-EL/-mhard-float"
    "generic-sim/-mabi=64/-EL/-msoft-float"
    "generic-sim/-mabi=64/-EB/-mhard-float"
    "generic-sim/-mabi=64/-EB/-msoft-float"
    "generic-sim/-mabi=n32/-EL/-mhard-float"
    "generic-sim/-mabi=n32/-EL/-msoft-float"
    "generic-sim/-mabi=n32/-EB/-mhard-float"
    "generic-sim/-mabi=n32/-EB/-msoft-float"
    "generic-sim/-mabi=32/-EL/-march=m5100/-mmicromips"
    "generic-sim/-mabi=32/-EL/-march=m5100"
    "generic-sim/-mabi=32/-EL/-march=m5101"
    "generic-sim/-mabi=32/-EL/-march=p5600"
    "generic-sim/-mabi=32/-EL/-mhard-float/-mnan=2008"
    "generic-sim/-mabi=32/-EL/-mhard-float"
    "generic-sim/-mabi=32/-EL/-msoft-float"
    "generic-sim/-mabi=32/-EL/-mhard-float/-mmicromips"
    "generic-sim/-mabi=32/-EL/-msoft-float/-mmicromips"
    "generic-sim/-mabi=32/-EB/-mhard-float/-mnan=2008"
    "generic-sim/-mabi=32/-EB/-mhard-float"
    "generic-sim/-mabi=32/-EB/-msoft-float"
    "generic-sim/-mabi=32/-EB/-mhard-float/-mmicromips"
    "generic-sim/-mabi=32/-EB/-msoft-float/-mmicromips"
    )

if [[ $CONFIG == mti ]]; then
    test_configs=( "${mti_configs[@]}" )
fi

#if [[ $CONFIG == img ]]; then
    test_configs=( "${test_configs[@]}" "${img_configs[@]}" )
#fi
    
function get_qemu_binary () {
    config=$1
    base=qemu-system-mips
    if [[ $config =~ -mabi=(n32|64) ]]; then
       base="$base"64
    fi
    if [[ $config =~ -EL ]]; then
       base="$base"el
    fi
    echo $base
}

function get_qemu_cpu () {
    config=$1
    cpu=""
    if [[ $config =~ -((mips32r6|mips64r6)|march=(i6400|i6500|p6600|m6201)) ]]; then
	if [[ $config =~ -mabi=(n32|64) ]]; then
	    cpu=I6400
	else
	    cpu=mips32r6-generic
	fi
    else
	if [[ $config =~ -mabi=(n32|64) ]]; then
	    cpu=MIPS64R2-generic
	else
	    if [[ $config =~ (mnan=2008|msoft-float) ]]; then
		cpu=P5600
	    else
		cpu=74Kf
	    fi
	fi
    fi
    echo $cpu
}

function get_link_script () {
    config=$1    
    if [[ $config =~ -mabi=64 ]]; then
       script=uhi64_64.ld
    elif [[ $config =~ -mabi=n32 ]]; then
	script=uhi64_n32.ld
    else
	script=uhi32.ld
    fi
    echo $script
}

jcount=0
declare -a jqueue

if [[ $RUNLIST =~ gcc ]]; then
    # manipulate the test_installed script to generate a modified site.exp
    sed 's|^set CFLAGS.*$|set CFLAGS \"\"\nset HOSTCC \"gcc\"\nset HOSTCFLAGS \"\"|' $SRCDIR/gcc/contrib/test_installed > $SRCDIR/gcc/contrib/test_installed.gcc"$$"
    chmod +x $SRCDIR/gcc/contrib/test_installed.gcc"$$"
    for cfg in "${test_configs[@]}"; do
	cfg=$cfg$EXTRA_CONF
	name="gcc_"`echo ${cfg#*/} | tr -d - | tr -d =  | tr / _`
	mkdir $name
	pushd $name > /dev/null
	rm -Rf site.exp
	DEJAGNU_SIM_LDSCRIPT=-T`get_link_script $cfg`
	DEJAGNU_SIM="$TOOLCHAIN/bin/`get_qemu_binary $cfg`"
	DEJAGNU_SIM_OPTIONS="-cpu `get_qemu_cpu $cfg` -semihosting -nographic -kernel"
	jcount=$(( jcount + 1 ))
	if [ $jcount -gt $JOB_MAX ]; then
	    wait ${jqueue[$((jcount - JOB_MAX))]}
	fi
	DEJAGNU_SIM_LDSCRIPT="$DEJAGNU_SIM_LDSCRIPT" DEJAGNU_SIM_OPTIONS="$DEJAGNU_SIM_OPTIONS" DEJAGNU_SIM="$DEJAGNU_SIM" DEJAGNU_SIM_LINK_FLAGS="-Wl,--defsym,__memory_size=32M" PATH=$TOOLCHAIN/bin:$HOSTTOOLS/bin:$SRCDIR/dejagnu:$PATH $SRCDIR/gcc/contrib/test_installed --without-gfortran --without-objc --without-g++ --with-gcc=$TOOLCHAIN/bin/$TRIPLET"-gcc" --prefix=$TOOLCHAIN --target=$TRIPLET --target_board=$cfg &> test.log &
	jqueue+=( $! )
	popd > /dev/null
    done
fi

if [[ $RUNLIST =~ g\+\+ ]]; then
	# manipulate the test_installed script to generate a modified site.exp
	sed 's|^set GCC_UNDER_TEST.*$|set GCC_UNDER_TEST \"${target+$target-}gcc\"\nset HOSTCC \"gcc\"\nset HOSTCLFAGS \"\"|' $SRCDIR/gcc/contrib/test_installed > $SRCDIR/gcc/contrib/test_installed.g++"$$"
	chmod +x $SRCDIR/gcc/contrib/test_installed.g++"$$"
        for cfg in "${test_configs[@]}"; do
	cfg=$cfg$EXTRA_CONF
	name="gxx_"`echo ${cfg#*/} | tr -d - | tr -d =  | tr / _`	
	mkdir $name
	pushd $name > /dev/null
	rm -Rf site.exp
	DEJAGNU_SIM_LDSCRIPT=-T`get_link_script $cfg`
	DEJAGNU_SIM="$TOOLCHAIN/bin/`get_qemu_binary $cfg`"
	DEJAGNU_SIM_OPTIONS="-cpu `get_qemu_cpu $cfg` -semihosting -nographic -kernel"
	jcount=$(( jcount + 1 ))
	if [ $jcount -gt $JOB_MAX ]; then
	    wait ${jqueue[$((jcount - JOB_MAX))]}
	fi
	DEJAGNU_SIM_LDSCRIPT="$DEJAGNU_SIM_LDSCRIPT" DEJAGNU_SIM_OPTIONS="$DEJAGNU_SIM_OPTIONS" DEJAGNU_SIM="$DEJAGNU_SIM" DEJAGNU_SIM_LINK_FLAGS="-Wl,--defsym,__memory_size=32M" PATH=$TOOLCHAIN/bin:$HOSTTOOLS/bin:$SRCDIR/dejagnu:$PATH $SRCDIR/gcc/contrib/test_installed --without-gfortran --without-objc --without-gcc --with-g++=$TRIPLET"-g++" --prefix=$TOOLCHAIN --target=$TRIPLET --target_board=$cfg &> test.log &
	jqueue+=( $! )
	popd > /dev/null
    done
fi

wait
# cleanup
rm -f $SRCDIR/gcc/contrib/test_installed.gcc"$$" $SRCDIR/gcc/contrib/test_installed.g++"$$"
