#!/bin/bash

declare -a github_packs
declare -a dmzportal_packs

# The following mirrors are fetched from github:
github_packs = ( "binutils-gdb" "cpython" "dejagnu" "gcc" "glibc"
		 "gnutools-qemu" "mips_tool_chain" "musl" "newlib" 
		 "overtest" "packages" "smallclib" "toolchain_docs"
		 "uclibc" )

# Fetched from dmz-portal. Not needed for overtest or toolchain release:
dmzportal_packs = ( "uTest" "codesize-test-suites" )

for p in github_packs; do
    git clone --bare --mirror https://github.com/MIPS/"$p".git
done

# The following mirrors are fetched from github:

for p in dmzportal_packs; do
    git clone --bare --mirror git://dmz-portal.mipstec.com/sec/"$p".git
done
