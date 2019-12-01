#!/bin/bash
#
# This script build and install mips linux gnu toolchain, llvm/clang
# and alternative clang driver.
#
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

wdr=$(readlink -f `dirname "$0"`)

# Settings
MAKE_JOBS=2         # Number of Make jobs
DLD_DIR=$PWD/dl     # Folder with packages
SRC_DIR=$PWD/src    # Folder for unpacked source code
BLD_DIR=$PWD/bld    # Build folder
ALT_DIR=$wdr        # Folder with alternative driver source code

# Alternative driver sources
# The script expects to find them in the same directory with the script.
alt_drv_items=(DriverConfig.py 
    gcc_generic.py
    gnu_parse.py
    Host.py
    mips_linux_gnu_g++
    mips_linux_gnu_gcc
    overall_options_module.py
    Utils.py)

if [ -z "$PREFIX" ] ; then
    echo "PREFIX must be definted" 1>&2
    exit 1
else
    export PATH=$PREFIX/bin:$PATH
fi

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "%%% Build toolchain"
${wdr}/build-mips-linux-gnu.sh \
    --download=$DLD_DIR --source=$SRC_DIR --build=$BLD_DIR \
    --jobs=$MAKE_JOBS || exit 1

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "%%% Build llvm/clang"
${wdr}/build-mips-clang.sh \
    --download=$DLD_DIR --source=$SRC_DIR --build=$BLD_DIR \
    --jobs=$MAKE_JOBS || exit 1

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "%%% Install alternative clang driver"
test -d ${PREFIX}/bin || mkdir ${PREFIX}/bin || exit 1
for f in ${alt_drv_items[@]} ; do
    cp -f "${ALT_DIR}/$f" ${PREFIX}/bin || exit 1
done

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "%%% Write README file
cat > ${PREFIX}/README <<END_OF_BIN_README
This package contains a binary Linux toolchain for MIPS, llvm/clang compiler
and alternate driver for clang. The C library is from egibc.

Quick Start
-----------------------------
1. Unpack the tarball to the /opt folder.
2. Add the /opt/mips-linux-toolchan/bin folder to the path.
END_OF_BIN_README
