#!/bin/bash

# to capture the commands, run the script with
# bash -x ./compile_all.sh .....
#

src=$1
basename=${1%.*}
echo $basename
llvm_bin=/home/rkotler/build_llvm_assembler/install/bin/
clang=${llvm_bin}/clang
llc=${llvm_bin}/llc

arm_base="${basename}-arm"
arm_ll="${arm_base}.ll"
arm_s="${arm_base}.s"
arm_o="${arm_base}.o"

$clang $src -o $arm_ll -emit-llvm -O3 -S -ccc-host-triple arm-unknown-linux -ccc-clang-archs arm
$llc $arm_ll -o $arm_s -march=arm
$llc $arm_ll -o $arm_o -march=arm -filetype=obj

mips_base="${basename}-mips"
mips_ll="${mips_base}.ll"
mips_s="${mips_base}.s"
mips_o="${mips_base}.o"
mips_as_o="${mips_base}-as.o"
mips_gas=/mips/arch/overflow/codesourcery/mips-linux-gnu/pro/update/2010.09-93/Linux/bin/mips-linux-gnu-gcc

$clang $src -o $mips_ll -emit-llvm -O3 -S -ccc-host-triple mipsel-unknown-linux -ccc-clang-archs mipsel
$llc $mips_ll -o $mips_s -mcpu=4ke -march=mipsel
$llc $mips_ll -o $mips_o -mcpu=4ke -march=mipsel -filetype=obj
$mips_gas -c -mips32r2 -EL -fPIC $mips_s -o $mips_as_o 

# x86
#
x86_base="${basename}-x86"
x86_ll="${x86_base}.ll"
x86_s="${x86_base}.s"
x86_o="${x86_base}.o"

$clang $src -o $x86_ll -O3 -S
#$llc $x86_ll -o $x86_s 
#$llc $x86_ll -o $x86_o -filetype=obj

