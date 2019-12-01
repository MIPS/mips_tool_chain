#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright (c) 2013, Imagination Technologies Limited.
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

function get_dir() {
  new_dir="$1"
  while /bin/true ; do
    read dir_response
    if [ "${dir_response}" = "" ] ; then
      dir_response=${new_dir}
    fi
    abs=`expr substr "${dir_response}" 1 1`
    if [ "${abs}" != "/" ] ; then
      echo "The path must be absolute (start with a /)."
    elif [ ! -e ${dir_response} ] ; then
      get_answer "Is it OK to create directory ${dir_response}?"
      if [ "${answer}" = "y" ] ; then
	mkdir -p ${dir_response}
	if [ ! -d ${dir_response} ] ; then
	  echo "For some reason I could not create directory ${dir_response}"
	  echo "Please enter a different directory name."
	else
	  answer=${dir_response}
	  return
	fi
      else
	echo "Please enter a different directory name."
      fi
    elif [ ! -d ${dir_response} ] ; then
      echo "${dir_response} exists but is not a directory."
      echo "Please enter a different directory name."
    else
      answer=${dir_response}
      return
    fi
  done
}

function get_answer() {
  query="$1"
  while /bin/true ; do
    echo -n "${query} "
    read response
    case ${response} in
      y|Y|Yes|yes|YES) answer="y"; return ;;
      n|N|No|no|NO)    answer="n"; return ;;
    esac
    echo "Sorry, I not understand your reply, please respond with 'y' or 'n'"
  done
}

# Initialize default directory names.

download_dir="$PWD"/downloads
source_dir="$PWD"/sources
build_dir="$PWD"/build
install_dir="$PWD/install"

# Ask questions to determine where to build the compiler and what multilibs
# to include.

echo "This script will generate a build script that you can run to download"
echo "and build a MIPS GCC compiler toolchain.  In order to do this, please"
echo "answer the following questions."

echo
echo "You can build a toolchain that targets linux platforms and uses glibc"
echo "for a runtime or a toolchain for baremetal platforms that uses newlib"
echo "for its runtime or both."
echo
get_answer "Do you want to build a toolchain for linux platforms?"
want_linux="${answer}"
echo
get_answer "Do you want to build a toolchain for baremetal platforms?"
want_elf="${answer}"
echo
echo "The toolchain is normally built from the latest released sources"
echo "but you can build from the latest development sources if you want."
echo "This is not recommended unless you have to have some functionality"
echo "that is not part of a official release yet."
echo
get_answer "Do you want to build from the latest unreleased sources?"
want_tot="${answer}"
echo
echo "The build script will download the necessary packages into:"
echo
echo "  ${download_dir}"
echo
echo "If this is OK enter [return], otherwise enter a new absolute path that"
echo "you would like to download the packages into."
echo

get_dir ${download_dir}
download_dir="${answer}"

echo
echo "Download directory is set to ${download_dir}"
echo

echo "The build script will unpack the source packages into:"
echo
echo "  ${source_dir}"
echo
echo "If this is OK enter [return], otherwise enter a new absolute path that"
echo "you would like to unpack the sources into."
echo

get_dir ${source_dir}
source_dir="${answer}"

echo
echo "Source directory is set to ${source_dir}"
echo

echo "The build script will build the packages in:"
echo
echo "  ${build_dir}"
echo
echo "If this is OK enter [return], otherwise enter a new absolute path that"
echo "you would like to build the packages."
echo

get_dir ${build_dir}
build_dir="${answer}"

echo
echo "Build directory is set to ${build_dir}"
echo

echo "The build script will install the packages in:"
echo
echo "  ${install_dir}"
echo
echo "If this is OK enter [return], otherwise enter a new absolute path that"
echo "you would like to install the packages into."
echo

get_dir ${install_dir}
install_dir="${answer}"

echo
echo "Install directory is set to ${install_dir}"
echo

tdir=`mktemp -d`
echo "int main(void) { return 0; }" > $tdir/x.c
gcc $tdir/x.c -o $tdir/x > /dev/null 2>&1
if [ ! -x $tdir ] ; then
	echo "You do not seem to have a working GCC compiler on this system."
	echo "I cannot build a toolchain without gcc."
	exit 1
fi
elftype=`file $tdir/x`
want_32bits="n"
case $elftype in
	*64-bit*) has_64bits="y" ;;
	*) has_64bits="n" ;;
esac
if [ "$has_64bits" = "y" ] ; then
	echo "The GCC compiler on your system generates 64-bit executables by default."
	get_answer "Do you want a 32-bit toolchain instead of a 64-bit one?"
	if [ "${answer}" = "y" ] ; then
		want_32bits="y"
	fi
	
fi
/bin/rm -rf $tdir

echo "The MIPS GCC compiler will generate code for the mips32r2"
echo "architecture by default, it can also support mips1, mips2, mips3,"
echo "mips4, mips32, mips64, and mips64r2 by use of the -march=ARCH flag."
echo "To support this, it is necessary to build libraries for these"
echo "architectures."
echo

get_answer "Do you want to build libraries for mips1?"
want_mips1="${answer}"
get_answer "Do you want to build libraries for mips2?"
want_mips2="${answer}"
get_answer "Do you want to build libraries for mips3?"
want_mips3="${answer}"
get_answer "Do you want to build libraries for mips4?"
want_mips4="${answer}"
get_answer "Do you want to build libraries for mips32?"
want_mips32="${answer}"
get_answer "Do you want to build libraries for mips64?"
want_mips64="${answer}"
get_answer "Do you want to build libraries for mips64r2?"
want_mips64r2="${answer}"

echo
echo "The MIPS bare-metal compiler can support generating compact code"
echo "with the -mips16 flag."
echo
get_answer "Do you want to build libraries for mips16?"
want_mips16="${answer}"
#get_answer "Do you want to build libraries for micromips?"
#want_micromips="${answer}"

echo
echo "The MIPS compiler generates big-endian code by default."
echo
get_answer "Do you want to build libraries for little-endian too?"
want_le="${answer}"

echo
echo "The MIPS compiler generates hard-float code by default."
echo
get_answer "Do you want to build libraries with soft-float too?"
want_soft="${answer}"

#echo
#echo "The MIPS compiler supports two representations for NaN's"
#echo "The legacy representation is what MIPS has historically used"
#echo "and is the default, the compiler also supports a representation"
#echo "that conforms to the IEEE2008 standard" 
#echo
#get_answer "Do you want to build libraries that support the IEEE2008 NaN format?"
#want_nan2008="${answer}"

echo
get_answer "Do you want to include the gdb debugger in your toolchain build?"
want_gdb="${answer}"

if [ "${want_linux}" = "y" ] ; then
	echo
	get_answer "Do you want to include the qemu simulator in your linux toolchain build?"
	want_qemu="${answer}"
fi

echo 
echo "Run the 'build-gcc.sh' script to download and build the GCC compiler"
echo "toolchain."
echo

echo "#!/bin/bash" > build-gcc.sh
echo "download_dir=${download_dir}" >> build-gcc.sh
echo "source_dir=${source_dir}" >> build-gcc.sh
echo "build_dir=${build_dir}" >> build-gcc.sh
echo "install_dir=${install_dir}" >> build-gcc.sh
echo "want_linux=${want_linux}" >> build-gcc.sh
echo "want_elf=${want_elf}" >> build-gcc.sh
echo "want_mips1=${want_mips1}" >> build-gcc.sh
echo "want_mips2=${want_mips2}" >> build-gcc.sh
echo "want_mips3=${want_mips3}" >> build-gcc.sh
echo "want_mips4=${want_mips4}" >> build-gcc.sh
echo "want_mips32=${want_mips32}" >> build-gcc.sh
echo "want_mips64=${want_mips64}" >> build-gcc.sh
echo "want_mips64r2=${want_mips64r2}" >> build-gcc.sh
echo "want_mips16=${want_mips16}" >> build-gcc.sh
#echo "want_micromips=${want_micromips}" >> build-gcc.sh
echo "want_le=${want_le}" >> build-gcc.sh
echo "want_soft=${want_soft}" >> build-gcc.sh
#echo "want_nan2008=${want_nan2008}" >> build-gcc.sh
echo "want_32bits=${want_32bits}" >> build-gcc.sh
echo "want_gdb=${want_gdb}" >> build-gcc.sh
echo "want_qemu=${want_qemu}" >> build-gcc.sh
echo "want_tot=${want_tot}" >> build-gcc.sh

chmod +x build-gcc.sh

# Everything after this point is copied exactly into build-gcc.sh with
# no changes.  The BUILD_EOF line should be the final line of this script.

cat << 'BUILD_EOF' >> build-gcc.sh

# -----------------------------------------------------------------------------
# Copyright (c) 2013, Imagination Technologies Limited.
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
gmp_ver=5.1.2
mpc_ver=1.0.1
mpfr_ver=3.1.2
binutils_ver=2.23.2
gcc_ver=4.8.1
linux_ver=2.6.39
glibc_ver=2.18
expat_ver=2.0.1
gdb_ver=7.6
qemu_ver=1.6.0
newlib_ver=2.0.0
if [ "${want_tot}" = "y" ] ; then
    binutils_gdb_ver=tot
    gcc_ver=tot
    glibc_ver=tot
    newlib_ver=tot
    qemu_ver=tot
fi

# Setup default patch list
patch_list="binutils-2.23.2.2014-04-11.patch newlib-2.0.0.2014-04-11.patch"

# Script name and path
prg=`basename "$0"`
wdr=$(readlink -f `dirname "$0"`)

# Check configuration options and make sure all neccessary initialization
# is done.

function check_configuration() {
  test -d "${source_dir}" || mkdir -p "${source_dir}"
  test -d "${build_dir}" || mkdir -p "${build_dir}"
  test -d "${download_dir}" || mkdir -p "${download_dir}"
  test -d "${install_dir}" || mkdir -p "${install_dir}"
  if [ ! -d "${source_dir}" ] ; then
    echo "Error: Could not create source directory (${source_dir})"
    exit 1
  fi  
  if [ ! -d "${build_dir}" ] ; then
    echo "Error: Could not create build directory (${build_dir})"
    exit 1
  fi  
  if [ ! -d "${install_dir}" ] ; then
    echo "Error: Could not create install directory (${install_dir})"
    exit 1
  fi  
  if [ ! -d "${download_dir}" ] ; then
    echo "Error: Could not create download directory (${download_dir})"
    exit 1
  fi  
}

configure_multilibs() {
  enable_64="n"
  OPTION_STRING=""
  DIR_STRING=""
  if [ "${want_mips1}" = "y" \
	-o "${want_mips2}" = "y" \
	-o "${want_mips3}" = "y" \
	-o "${want_mips4}" = "y" \
	-o "${want_mips32}" = "y" \
	-o "${want_mips64}" = "y" \
	-o "${want_mips64r2}" = "y" ] ; then
    if [ "${want_mips1}" = "y" ] ; then
      OPTION_STRING="${OPTION_STRING}/mips1"
      DIR_STRING="${DIR_STRING} mips1"
    fi
    if [ "${want_mips2}" = "y" ] ; then
      OPTION_STRING="${OPTION_STRING}/mips2"
      DIR_STRING="${DIR_STRING} mips2"
    fi
    if [ "${want_mips3}" = "y" ] ; then
      OPTION_STRING="${OPTION_STRING}/mips3"
      DIR_STRING="${DIR_STRING} mips3"
    fi
    if [ "${want_mips4}" = "y" ] ; then
      OPTION_STRING="${OPTION_STRING}/mips4"
      DIR_STRING="${DIR_STRING} mips4"
    fi
    if [ "${want_mips32}" = "y" ] ; then
      OPTION_STRING="${OPTION_STRING}/mips32"
      DIR_STRING="${DIR_STRING} mips32"
    fi
    if [ "${want_mips64}" = "y" ] ; then
      OPTION_STRING="${OPTION_STRING}/mips64"
      DIR_STRING="${DIR_STRING} mips64"
    fi
    if [ "${want_mips64r2}" = "y" ] ; then
      OPTION_STRING="${OPTION_STRING}/mips64r2"
      DIR_STRING="${DIR_STRING} mips64r2"
    fi
    t=${OPTION_STRING}
    OPTION_STRING=`echo "${t}" | sed -e 's,^/, ,'`
  fi
  if [ "${want_mips64}" = "y" -o "${want_mips64r2}" = "y" ] ; then
    OPTION_STRING="${OPTION_STRING} mabi=64"
    DIR_STRING="${DIR_STRING} 64"
    enable_64="y"
  fi
  if [ "${want_mips16}" = "y" ] ; then
    OPTION_STRING="${OPTION_STRING} mips16"
    DIR_STRING="${DIR_STRING} mips16"
  fi
  if [ "${want_le}" = "y" ] ; then
    OPTION_STRING="${OPTION_STRING} EL"
    DIR_STRING="${DIR_STRING} el"
  fi
  if [ "${want_soft}" = "y" ] ; then
    OPTION_STRING="${OPTION_STRING} msoft-float"
    DIR_STRING="${DIR_STRING} sof"
  fi

  if [ "${target}" = "mips-mti-linux-gnu" ] ; then
    multilib_file=${source_dir}/gcc-${gcc_ver}/gcc/config/mips/t-mti-linux
  else
    multilib_file=${source_dir}/gcc-${gcc_ver}/gcc/config/mips/t-mti-elf
  fi

  if [ ! -f ${multilib_file}.orig ] ; then
    cp ${multilib_file} ${multilib_file}.orig
  fi
  cat ${multilib_file}.orig | \
	sed -e "s,^MULTILIB_OPTIONS =.*$,MULTILIB_OPTIONS =${OPTION_STRING}," \
	    -e "s,^MULTILIB_DIRNAMES =.*$,MULTILIB_DIRNAMES =${DIR_STRING}," \
		> ${multilib_file}.new

  if [ "${want_mips1}" = "y" -a "${enable_64}" = "y" ] ; then
    echo "MULTILIB_EXCEPTIONS += *mips1*/*mabi=64*" >> ${multilib_file}.new
  fi
  if [ "${want_mips2}" = "y" -a "${enable_64}" = "y" ] ; then
    echo "MULTILIB_EXCEPTIONS += *mips2*/*mabi=64*" >> ${multilib_file}.new
  fi

  cmp -s ${multilib_file}  ${multilib_file}.new
  if [ $? -eq 1 ] ; then
    rm -f ${multilib_file}
    cp ${multilib_file}.new ${multilib_file}
  fi 
}

# Standard build function
function build_package() {
  package_name="$1"
  package_src="$2"
  configure_opts="$3"
  cd ${build_dir}
  if [ "${want_32bits}" = "y" ] ; then
    export CC='gcc -m32'
    export CXX='g++ -m32'
  fi
  if [ ! -d ${package_name}-${target} ] ; then
    mkdir ${package_name}-${target}
    cd ${package_name}-${target}
    ${package_src}/configure ${configure_opts}
    if [ $? -ne 0 ] ; then
      echo "Error: Configure of package ${package_name} failed."
      exit 1
    fi
  else
    cd ${package_name}-${target}
  fi
  if [ "${package_name}" = "gcc-initial" ] ; then
    if [ "${target}" = "mips-mti-linux-gnu" ] ; then
      make ${make_opts} all
      if [ $? -ne 0 ] ; then
	echo "Error: Make of package ${package_name} failed."
	exit 1
      fi
      make ${make_opts} install
      if [ $? -ne 0 ] ; then
	echo "Error: Make install of package ${package_name} failed."
	exit 1
      fi
    else
      make ${make_opts} all-gcc
      if [ $? -ne 0 ] ; then
	echo "Error: Make of package ${package_name} failed."
	exit 1
      fi
      make ${make_opts} install-gcc
      if [ $? -ne 0 ] ; then
	echo "Error: Make install of package ${package_name} failed."
	exit 1
      fi
    fi
  else
    make ${make_opts} all
    if [ $? -ne 0 ] ; then
      echo "Error: Make of package ${package_name} failed."
      exit 1
    fi
    # newlib make install does not work with parallel make.
    if [ "${package_name}" = "newlib" ] ; then
      make install
      if [ $? -ne 0 ] ; then
	echo "Error: Make install of package ${package_name} failed."
	exit 1
      fi
    else
      make ${make_opts} install
      if [ $? -ne 0 ] ; then
	echo "Error: Make install of package ${package_name} failed."
	exit 1
      fi
    fi
  fi
}

# check function (currently only supports GCC)
function check_package() {
  package_name="$1"
  cd ${build_dir}
  if [ "${package_name}" != "gcc" ] ; then
    echo "Error: Check for product ${package_name} is not implemented."
    exit 1
  fi
  if [ ! -d ${package_name} ] ; then
    echo "Error: build directory for package ${package_name} does not exist."
    exit 1
  fi
  cd ${package_name}
  if [ "${target}" = "mips-mti-elf" ] ; then
    make -k ${make_opts} RUNTESTFLAGS=\"--target_board='mips-sim-mti32\{-mips1,-mips32r2\}'\" check
  else
    echo "Error: Checking this target is not supported."
    exit 1
  fi
}

# Install linux headers
function install_linux_headers() {
  cd ${source_dir}/linux-${linux_ver}
  make ${make_opts} headers_install ARCH=mips INSTALL_HDR_PATH=${sysroot_dir}/usr 
  if [ $? -ne 0 ] ; then
    echo "Error: Make of linux header files failed."
    exit 1
  fi
}

# Build glibc
function build_glibc() {

  cd ${build_dir}
  if [ ! -d glibc ] ; then
    mkdir glibc
  fi

  ${target}-gcc --print-multi-lib | while read ml
  do
    nn=`echo ${ml} | sed -e 's/;.*$//' -e 's,/,_,g' -e 's/\./default/'`
    glibc_objdir=glibc_${nn}
    dd=`echo ${ml} | sed -e 's/;.*$//'`
    if [ "${dd}" = "." ] ; then
      exec_prefix="/usr"
    else
      exec_prefix="/${dd}/usr"
    fi
    gcc_flags=`echo ${ml} | sed -e 's/^.*;//' -e 's/@/ -/g'`
    glibc_config_opts=""
    case ${gcc_flags} in
	*soft-float*) glibc_config_opts="${glibc_config_opts} --without-fp" ;;
    esac
    case ${gcc_flags} in
      *mips32*) libc_target=${target} ;;
      *mips3*|*mips4*|*mips64*) libc_target=`echo ${target} | sed -e 's/^mips-mti/mips64-mti/'` ;;
      *) libc_target=${target} ;;
    esac
    export BUILD_CC=gcc
    export AR=${target}-ar
    export RANLIB=${target}-ranlib
    export CC="${target}-gcc ${gcc_flags}"
    export CXX="${target}-g++ ${gcc_flags}"

    cd ${build_dir}/glibc
    if [ ! -d ${glibc_objdir} ] ; then
      mkdir ${glibc_objdir}
      cd ${glibc_objdir}
      ${source_dir}/glibc-${glibc_ver}/configure \
	--prefix=/usr/fake --with-headers=${sysroot_dir}/usr/include \
	--build=i686-pc-linux-gnu --host=${libc_target} \
	--disable-profile --without-gd --without-cvs \
	--enable-add-ons ${glibc_config_opts}
    else
      cd ${glibc_objdir}
    fi
    make ${make_opts}
    make ${make_opts} \
		install install_root=${sysroot_dir} \
		exec_prefix=${exec_prefix} \
		prefix=/usr \
		slibdir=/usr/lib \
		inst_slibdir=${sysroot_dir}/${exec_prefix}/lib \
		libdir=/usr/lib \
		inst_libdir=${sysroot_dir}/${exec_prefix}/lib \
		rtlddir=/usr/lib \
		inst_rtlddir=${sysroot_dir}/${exec_prefix}/lib

    unset BUILD_CC AR RANLIB CC CXX
  done
}

function get_package() {
  package_name="$1"
  package_version="$2"
  package_type="$3"
  remote_location="$4"
  git_repo="$5"

  local wget_opts="-t 10 -nv" 

  if [ "${git_repo}" = "" -a "${package_version}" = "tot" ] ; then
    echo "Error: No git repository given for ${package_name} ToT sources."
    exit 1
  fi
  if [ "${git_repo}" != "" -a "${package_version}" != "tot" ] ; then
    echo "Error: Git repository given for ${package_name} released sources."
    exit 1
  fi

  package_dir_name="${package_name}-${package_version}"
  if [ "${package_version}" = "tot" ] ; then
    (cd ${source_dir}; git clone ${git_repo} ${package_dir_name})
  else
    package_bundle_name="${package_dir_name}.${package_type}"
    if [ ! -e "${download_dir}/${package_bundle_name}" ] ; then
      wget ${wget_opts} -O ${download_dir}/${package_bundle_name} \
	   ${remote_location}/${package_bundle_name}
    fi
    if [ ! -e "${download_dir}/${package_bundle_name}" ] ; then
      echo "Error: Could not download package ${package_name} from ${remote_location}"
      exit 1
    fi
    if [ ! -d ${source_dir}/${package_dir_name} ] ; then
      (cd ${source_dir}; tar -xvf ${download_dir}/${package_bundle_name})
    fi
  fi

  if [ ! -d ${source_dir}/${package_dir_name} ] ; then
    echo "Error: Could not unpack package ${package_name} into ${source_dir}/${package_dir_name}"
    exit 1
  fi
}

# Download any needed packages
function setup_sources() {
  get_package gmp ${gmp_ver} tar.lz \
    ftp://ftp.gmplib.org/pub/gmp-${gmp_ver}
  get_package mpfr ${mpfr_ver} tar.bz2 \
    http://www.mpfr.org/mpfr-${mpfr_ver}
  get_package mpc ${mpc_ver} tar.gz \
    http://www.multiprecision.org/mpc/download
  if [ "${want_tot}" = "y" ] ; then
    get_package binutils-gdb ${binutils_gdb_ver} bogus \
      http://example.com/bogus \
      git://sourceware.org/git/binutils-gdb.git
  else
    get_package binutils ${binutils_ver} tar.bz2 \
      http://ftp.gnu.org/gnu/binutils
    if [ "${want_gdb}" = "y" ] ; then
      get_package gdb ${gdb_ver} tar.bz2 \
        http://ftp.gnu.org/gnu/gdb
    fi
  fi
  get_package gcc ${gcc_ver} tar.bz2 \
    ftp://ftp.gnu.org/gnu/gcc/gcc-${gcc_ver} \
    git://gcc.gnu.org/git/gcc.git
  if [ "${want_linux}" = "y" ] ; then
    get_package glibc ${glibc_ver} tar.bz2 \
      http://ftp.gnu.org/gnu/libc \
      git://sourceware.org/git/glibc.git
    major_kernel_ver=`echo ${linux_ver} | sed 's/\.[0-9]*\$//'`
    get_package linux ${linux_ver} tar.bz2 \
      http://www.kernel.org/pub/linux/kernel/v${major_kernel_ver}
    if [ "${want_qemu}" = "y" ] ; then
      get_package qemu ${qemu_ver} tar.bz2 \
        http://wiki.qemu.org/download \
        git://git.qemu-project.org/qemu.git
    fi
  fi
  if [ "${want_elf}" = "y" ] ; then
    get_package newlib ${newlib_ver} tar.gz \
      ftp://sources.redhat.com/pub/newlib \
      git://sourceware.org/git/newlib.git
  fi
}

function setup_patches() {
  local wget_opts="-t 10 -nv --no-check-certificate"
  local patch_url="https://github.com/MIPS/gcc/patches/"
  for p in $patch_list ; do
    if [ ! -e ${download_dir}/${p} ] ; then
      product=`echo $p | sed 's/.patch$//'`
      if [ -d ${source_dir}/${product} ] ; then
	wget ${wget_opts} -O ${download_dir}/${p} ${patch_url}/${p}
	if [ ! -f ${download_dir}/${p} ] ; then
	  echo "Error: Could not download patch ${patch_url}/${p}"
	  exit 1
	fi
	cd ${source_dir}/${product}
	patch -t -p 1 < ${download_dir}/${p}
	if [ $? -ne 0 ] ; then
	  echo "Error: Could not apply patch ${download_dir}/${p} to package ${product}"
	  exit 1
	fi
      fi
    fi
  done
}

function setup_links() {
  gcc_dir=${source_dir}/gcc-${gcc_ver}
  gmp_dir=${source_dir}/gmp-${gmp_ver}
  mpfr_dir=${source_dir}/mpfr-${mpfr_ver}
  mpc_dir=${source_dir}/mpc-${mpc_ver}
  cd ${gcc_dir}
  if [ ! -e gmp ] ; then
    ln -s ${gmp_dir} gmp
  fi
  if [ ! -e mpfr ] ; then
    ln -s ${mpfr_dir} mpfr
  fi
  if [ ! -e mpc ] ; then
    ln -s ${mpc_dir} mpc
  fi
}


build_toolchain () {
  target="$1"
  prefix_dir="${install_dir}/${target}"
  sysroot_dir="${install_dir}/${target}/sysroot"

  binutils_configure_options=" \
	--prefix=${prefix_dir} \
	--target=${target} \
	--with-sysroot=${sysroot_dir}"

  gdb_configure_options=" \
	--prefix=${prefix_dir} \
	--target=${target}"

  binutils_gdb_configure_options="${binutils_configure_options}"

  gcc_initial_configure_options=" \
	--prefix=${prefix_dir} \
       	--target=${target} \
	--enable-languages=c \
	--with-newlib --without-headers \
	--with-mips-plt \
	--disable-shared --disable-threads \
	--disable-libquadmath --disable-libatomic \
       	--disable-libssp --disable-libgomp \
	--disable-libmudflap --disable-decimal-float"

  gcc_configure_options=" \
	--prefix=${prefix_dir} \
       	--target=${target} \
       	--enable-languages=c,c++ \
	--with-mips-plt \
       	--disable-libssp --disable-libgomp \
	--disable-libmudflap --disable-fixed-point \
	--disable-decimal-float"
  if [ "${target}" = "mips-mti-linux-gnu" ] ; then
    gcc_configure_options="${gcc_configure_options} \
	--with-sysroot=${sysroot_dir} \
	--with-build-sysroot=${sysroot_dir} \
	--enable-__cxa_atexit"
  else
   gcc_configure_options="${gcc_configure_options} \
	--with-newlib"
  fi

  QEMU_TARGETS="mips-linux-user"
  if [ "${want_le}" = "y" ] ; then
    QEMU_TARGETS="$QEMU_TARGETS,mipsel-linux-user"
  fi
  if [ "${want_mips64}" = "y" -o "${want_mips64r2}" = "y" ] ; then
    QEMU_TARGETS="$QEMU_TARGETS,mipsn32-linux-user,mips64-linux-user"
    if [ "${want_le}" = "y" ] ; then
      QEMU_TARGETS="$QEMU_TARGETS,mipsn32el-linux-user,mips64el-linux-user"
    fi
  fi
  qemu_configure_options=" \
	--prefix=${prefix_dir} \
	--interp-prefix=${sysroot_dir} \
	--disable-tools --disable-system --disable-werror \
	--target-list=${QEMU_TARGETS}"

  newlib_configure_options=" \
	--prefix=${prefix_dir} \
	--target=${target}"

  make_opts="-j 3"
  export PATH=${prefix_dir}/bin:$PATH

  configure_multilibs

  if [ "$want_tot" = "y" ] ; then
    build_package binutils-gdb ${source_dir}/binutils-gdb-${binutils_gdb_ver} "${binutils_gdb_configure_options}"
  else
    build_package binutils ${source_dir}/binutils-${binutils_ver} "${binutils_configure_options}"
  fi
  build_package gcc-initial ${source_dir}/gcc-${gcc_ver} "${gcc_initial_configure_options}"
  if [ "${target}" = "mips-mti-linux-gnu" ] ; then
    install_linux_headers
    build_glibc
  else
    build_package newlib ${source_dir}/newlib-${newlib_ver} "${newlib_configure_options}"
  fi
  build_package gcc ${source_dir}/gcc-${gcc_ver} "${gcc_configure_options}"
  if [ "${want_gdb}" = "y" -a "${build_tot}" = "n" ] ; then
    build_package gdb ${source_dir}/gdb-${gdb_ver} "${gdb_configure_options}"
  fi
  if [ "${target}" = "mips-mti-linux-gnu" -a "${want_qemu}" = "y" ] ; then
    build_package qemu ${source_dir}/qemu-${qemu_ver} "${qemu_configure_options}"
  fi
  #check_package gcc
}

# Begin the actual download/build process.

# These steps only need to be done once, no matter how many toolchains
# we build.

check_configuration
setup_sources
setup_patches
setup_links

# Now we need to create the target_list and loop through each toolchain.

if [ "${want_linux}" = "y" ] ; then
  if [ "${want_elf}" = "y" ] ; then
    target_list="mips-mti-linux-gnu mips-mti-elf"
  else
    target_list="mips-mti-linux-gnu"
  fi
else
  if [ "${want_elf}" = "y" ] ; then
    target_list="mips-mti-elf"
  else
    echo "Error: No targets specified."
    exit 1
  fi
fi

for target in $target_list
do
  build_toolchain $target
done
exit 0  
BUILD_EOF
