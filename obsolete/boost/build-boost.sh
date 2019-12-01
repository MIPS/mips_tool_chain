#!/bin/bash
#
# Boost library build script.
# Copyright 2011 MIPS Technologies.
#

function get_boost_fname() {
    local ver=$1
    echo "boost_${ver//./_}"
}

function download_boost() {
    local ver=$1
    local dname=`dirname $2`
    local fname=`basename $2`

    echo %%% Download Boost package

    if [ ! -d "$dname" ]; then
        mkdir -p $dname
    fi

    wget -t 10 -O "$dname/$fname" \
        http://downloads.sourceforge.net/project/boost/boost/$ver/$fname \
    || exit 1
}

function extract_tar() {
    local arc=$1

    echo %%% Extract Boost package

    if [ ! -d "$src_dir" ]; then
        mkdir -p $src_dir
    fi

    tar -C $src_dir --bzip2 -xf $arc \
    || exit 1
}

function build_b2() {
    local src=$1

    echo %%% Build b2 tool

    cd $src/tools/build/v2

    ./bootstrap.sh --with-toolset=$toolset \
    && ./b2 --prefix=$prefix toolset=gcc install \
    || exit 1
}

function build_boost() {
    local src_dir=$1
    local bld_dir=$2

    echo %%% Build Boost library

    if [ ! -d "$bld_dir" ]; then
        mkdir -p $bld_dir
    fi

    cd $src_dir

    $prefix/bin/b2 toolset=$toolset \
        link=static variant=debug \
        -j2 --build-dir=$bld_dir --without-mpi \
        --prefix=$prefix install \
    || exit 1
}

function print_usage() {
    echo "USAGE:"
    echo "  `basename $1` [OPTIONS] COMMAND"
    echo ""
    echo "COMMAND"
    echo "  download   download package to the download dir"
    echo "  extract    extract packages to the src dir"
    echo "  b2         build and install Boost build tools"
    echo "  boost      build and install Boost library"
    echo "  all        run all steps"
    echo ""
    echo "OPTIONS"
    echo "  -p         installation folder prefix"
    echo "  -v         Boost version like 1.47.0"
    echo "  -t         Boost toolset (gcc, clang ...)"
    echo "  -d         folder to store downloaded packages"
    echo "  -s         folder to extract downloaded packages"
    echo "  -b         folder to build packages"
}

function parse_opts() {
    while getopts "p:v:t:d:s:b:h" opt; do
        case $opt in
            p)
                prefix=$OPTARG
                ;;
            v)
                boost_ver=$OPTARG
                ;;
            t)
                toolset=$OPTARG
                ;;
            d)
                dld_dir=$OPTARG
                ;;
            s)
                src_dir=$OPTARG
                ;;
            b)
                bld_dir=$OPTARG
                ;;
            h)
                print_usage $0
                exit 0
                ;;
            ?)
                print_usage $0
                exit 1
                ;;
        esac
    done

    shift $((OPTIND-1))

    if [ ! -z "$1" ]; then
        cmd=$1
    fi
}

function print_config() {
    echo "Configuration: ($cmd)"
    echo "  Prefix:    $prefix"
    echo "  Boost ver: $boost_ver"
    echo "  Toolset:   $toolset"
    echo "  Download:  $dld_dir"
    echo "  Source:    $src_dir"
    echo "  Build:     $bld_dir"
    echo ""
}

# Initialize default configuration
cmd=all
prefix=$PREFIX
boost_ver=1.47.0
toolset=gcc
dld_dir=`pwd`/dld
src_dir=`pwd`/src
bld_dir=`pwd`/bld

parse_opts $*

if [ -z "$prefix" ]; then
    echo Installation folder prefix not found.
    echo Setup PREFIX variables or use -p argument.
    print_usage $0
    exit 1
fi

prefix=$(readlink -f $prefix)
dld_dir=$(readlink -f $dld_dir)
src_dir=$(readlink -f $src_dir)
bld_dir=$(readlink -f $bld_dir)

boost_tar="$dld_dir/$(get_boost_fname $boost_ver).tar.bz2"
boost_src="$src_dir/$(get_boost_fname $boost_ver)"
boost_bld="$bld_dir/$(get_boost_fname $boost_ver)"

case $cmd in
    download)
        print_config
        download_boost $boost_ver $boost_tar
        ;;
    extract)
        print_config
        extract_tar $boost_tar
        ;;
    b2)
        print_config
        build_b2 $boost_src
        ;;
    boost)
        print_config
        build_boost $boost_src $boost_bld
        ;;
    all)
        print_config
        if [ ! -f "$boost_tar" ]; then
            download_boost $boost_ver $boost_tar
        fi
        extract_tar $boost_tar
        build_b2 $boost_src
        build_boost $boost_src $boost_bld
        ;;
    *)
        print_usage $0
        exit 1
        ;;
esac
