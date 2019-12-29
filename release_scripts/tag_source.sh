#!/bin/bash

OPTS=`getopt -o p:e:l:dcvh --long path:,elf:,linux:,dry-run,clear-tags,verify,help -n 'parse options' -- "$@"`
eval set -- "$OPTS"

rootdir=""
testid=0
testid_linux=0
dry_run=0
clear=0
verify=0

while true ; do
    case $1 in
	-p|--path) rootdir=$2; shift 2;;
	-e|--elf) testid=$2; shift 2;;
	-l|--linux) testid_linux=$2; shift 2;;
	-d|--dry-run) dry_run=1; shift;;
	-c|--clear-tags) clear=1; shift;;
	-v|--verify) verify=1; shift;;
	-h|--help)
	    echo "	--path=<path_to_checked_out_sources>"
	    echo "	--elf=<ELF toolchain overtest id>"
	    echo "	--linux=<Linux toolchain overtest id>"
	    echo "	--dry-run	Print commands only)"
	    echo "	--clear-tags	Delete existing tags instead of creating them)"
	    echo "	--verify	Verify that the tags are applied and committed"
	    echo "	--help		Print this message"
	    shift; exit; break;;
	--) shift; break;;
	*) echo "Unrecognized option, try $0 --help";
	   exit 1
	   break;;
    esac
done

if [ $dry_run -eq 1 ]; then
    maybe_doit=echo
else
    maybe_doit=
fi

python --version 2>&1 | grep -q -e "Python 2"
if [ $? -ne 0 ]; then
    echo "ERROR: Python executable " `which python` " is not python v2"
    exit 1
fi

if [ -z $rootdir ]; then
    echo "ERROR: Required option: --path=<path_to_checked_out_sources>"
    exit 1
elif [ ! -d $rootdir ]; then
    echo "ERROR: No such directory: $rootdir"
    exit 1
fi

if [ $testid -eq 0 ]; then
    echo "ERROR: Required option: --elf=<ELF toolchain overtest id>"
    exit 1
fi

if [ $testid_linux -eq 0 ]; then
    echo "ERROR: Required option: --linux=<Linux toolchain overtest id>"
    exit 1
fi

if [ ! -d $rootdir/overtest ]; then
    echo "Checking out overtest"
    git clone ssh://gitosis@dmz-portal.mipstec.com/sec/overtest $rootdir/overtest
fi

if [ ! -d $rootdir/mips_tool_chain ]; then
    echo "Checking out mips_tool_chain"
    git clone ssh://git@github.com/MIPS/mips_tool_chain $rootdir/mips_tool_chain
fi

python $rootdir/overtest/overtest.py --export --schema=testrun -i $testid > /dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Invalid ELF testrun ID: $testid"
    exit 1
fi

python $rootdir/overtest/overtest.py --export --schema=testrun -i $testid_linux > /dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Invalid Linux testrun ID: $testid_linux"
    exit 1
fi

# if gpg-agent is not already running, then start it
if [ $( ps ux | grep -c -e gpg-agent ) -eq 2 ]; then
    source ~/.gpgring.`hostname`
else
    export GPG_TTY=$(tty)
    gpg-agent --daemon -s > ~/.gpgring.`hostname`
    source ~/.gpgring.`hostname`
fi

cd $rootdir

version=`python $rootdir/overtest/overtest.py --export --schema=testrun -i $testid | grep -e "Release Version:" | cut -d: -f2 | tr -d \ `
arch=`python $rootdir/overtest/overtest.py --export --schema=testrun -i $testid | grep -e "Architecture:" | cut -d: -f2 | tr -d \ `

if [ $arch == "mips" ]; then
    packages="binutils gcc gdb gold newlib uclibc packages qemu smallclib glibc dejagnu python"
    tprefix="MIPS-"
elif [ $arch == "nanomips" ]; then
    packages="binutils gcc gdb gold newlib packages qemu smallclib musl dejagnu python"
    tprefix="nanoMIPS-"
fi

# Checkout or verify that sources exist
for p in $packages; do
    # Fetch the repo-name and translate to writeable (secure) URL
    repo=`python $rootdir/overtest/overtest.py --export --schema=testrun -i $testid --automatic | grep -i -e "$p Remote:" | cut -d: -f3  | tr -d \'\ `
    if [ -z "$repo" ]; then
	repo=`python $rootdir/overtest/overtest.py --export --schema=testrun -i $testid_linux --automatic | grep -i -e "$p Remote:" | cut -d: -f3  | tr -d \'\ `
    fi
    # Translate ://<url> to ssh://git@<url>
    repo=${repo/\/\//ssh:\/\/git@}

    # Fetch the branch-name
    branch=`python $rootdir/overtest/overtest.py --export --schema=testrun -i $testid --automatic | grep -i -e "$p Branch:" | cut -d: -f2  | tr -d \'\ `
    if [ -z "$branch" ]; then
	branch=`python $rootdir/overtest/overtest.py --export --schema=testrun -i $testid_linux --automatic | grep -i -e "$p Branch:" | cut -d: -f2  | tr -d \'\ `
    fi

    if [ -d $p/.git ]; then
	# repo already cloned
	if [ -z "`grep -e ssh:\/\/git@ $rootdir/$p/.git/config`" ]; then
	    echo "$rootdir/$p checked out from read-only repository"
	    exit 1
	fi
	pushd $p
	git fetch origin $branch
	if [ $? -ne 0 ]; then
	    git fetch
	fi
	popd
    else
	# Checkout the branch
	$rootdir/mips_tool_chain/build_scripts/build_toolchain update --branch=$p:$branch --source=$rootdir --git_ref=/scratch/overtest/git/$p".git" --src=$p:$repo $p
	if [[ $? -ne 0 || ! -d $p/.git ]]; then
	    echo "Failed to checkout $p:$branch from $repo"
	    exit 1
	fi
    fi
done

if [ $arch == "nanomips" ]; then
    packages="$packages toolchain_docs"
    if [ ! -d $rootdir/toolchain_docs/.git ]; then
	git clone -b master ssh://git@github.com/MIPS/toolchain_docs
	if [ ! -d $rootdir/toolchain_docs/.git ]; then
	    echo "Failed to checkout toolchain_docs"
	    exit 1
	fi
    fi
fi

for p in $packages; do
    srcdir=$p

    # gdb/gold share repo with binutils, so they need different tag names
    if [[ "$p" == gdb || "$p" == gold ]]; then
	tag=`echo $tprefix $p | awk '{print $1 toupper ($2) "-"}'`$version
    else
	tag=$tprefix$version
    fi

    # fetch the version number
    rev=`python $rootdir/overtest/overtest.py --export --schema=testrun -i $testid --automatic | grep -i -e "$p rev:" | cut -d: -f2  | tr -d \'\ `
    if [ -z "$rev" ]; then
	rev=`python $rootdir/overtest/overtest.py --export --schema=testrun -i $testid_linux --automatic | grep -i -e "$p rev:" | cut -d: -f2  | tr -d \'\ `
    fi

    pushd $srcdir
    tag_check=`git tag -l $tag`

    if [ $clear -eq 1 ]; then
	if [ -n "$tag_check" ]; then
	    $maybe_doit git tag -d $tag
	    $maybe_doit git push --delete origin $tag
	else
	    echo $p: not tagged with $tag
	fi
    elif [ $verify -eq 1 ]; then
	if [ -z "$tag_check" ]; then
	    echo $p: not tagged with $tag
	else
	    git tag -v $tag
	    if [ $? -ne 0 ]; then
		echo "ERROR: Failed to verify $tag on $p"
		exit 1
	    fi
	    git ls-remote --tags origin | grep -q -e $tag
	    if [ $? -ne 0 ]; then
		echo "WARNING: $p:$tag local only, not on remote!!"
	    fi
	fi
    else
	if [ -z "$tag_check" ]; then
	    $maybe_doit git tag -s $tag $rev -m "$tprefix$version release tag for $p"
	    echo
	    $maybe_doit git push origin $tag
	else
	    echo $p: already tagged with $tag
	fi
    fi

    popd
done
