#!/bin/bash -x

OPTS=`getopt -o b:i:a:t:uh --long bucket:,id:,arch:,toolchain:,update-latest,help -n 'parse options' -- "$@"`
eval set -- "$OPTS"

toolchain=
arch=mips
bucket=
id=
latest=""

while true ; do
    case $1 in
	-b|--bucket) bucket=$2; shift 2;;
	-i|--id) distid=$2; shift 2;;
	-a|--arch) arch=$2; shift 2;;
	-t|--toolchain) toolchain=$2; shift 2;;
	-u|--update-latest) latest=1; shift;;
	-h|--help)
	    echo "	--bucket=<s3 bucket path>"
	    echo "	--id=<CloudFront distribution ID>"
	    echo "	--arch=<mips|nanomips>"
	    echo "	--toolchain=<path_to_toolchain_tarballs>"
	    echo "	--update-latest	Update link to latest toolchain"
	    echo "	--help		Print this message"
	    shift; exit; break;;
	--) shift; break;;
	*) echo "Unrecognized option, try $0 --help";
	   exit 1
	   break;;
    esac
done

version=`basename $toolchain`
if [ ! -d $toolchain ]; then
    echo "Toolchain path not found: $toolchain"
    exit 1
fi

if [ -z $bucket ]; then
    echo "S3 bucket must be specified"
    exit 1
fi

if [ "x$latest" != "x" ]; then
    if [ -z $distid ]; then
	echo "CloudFront distribution ID is required to update latest toolchain links"
	exit 1
    fi
fi

if [ $arch = nanomips ]; then
    relpath=toolchain/nanomips
    s3path=$bucket/$relpath/$version
elif [ $arch = mips ]; then
    relpath=toolchain
    s3path=$bucket/$relpath/$version
else
    echo "ARCH must be from [mips|nanomips]"
    exit 1
fi

function check_file_exists () {
    fname=$1
    if [ ! -f $toolchain/$fname ]; then
	echo "Toolchain path missing $fname"
	exit 1
    fi
}

check_file_exists releasenotes.html
check_file_exists downloads.html
check_file_exists index.html

if [ ! -d $toolchain/src ]; then
    echo "Toolchain path is missing source directory"
    exit 1
fi

s3cmd -P put -m text/css $toolchain/style.css $s3path/
s3cmd -P put $toolchain/*.html $s3path/
s3cmd -P put --recursive $toolchain/src $s3path/
s3cmd -P put --recursive $toolchain/images $s3path/
s3cmd -P put $toolchain/*.tar.gz $s3path/

if [ -d $toolchain/docs ]; then
    s3cmd -P put --recursive $toolchain/docs $s3path/
fi

if [ "x$latest" != "x" ]; then
    # Upload index.html to latest
    s3cmd -P put --add-header="x-amz-website-redirect-location: /components/$relpath/$version/index.html" $toolchain/index.html $bucket/$relpath/latest/index.html

    which aws
    if [ $? -ne 0 ]; then
       if [ -f /opt/rh/rh-python36/enable ]; then
	   source /opt/rh/rh-python36/enable
       else
	   echo  "ERROR: Couldn't find aws"
	   exit
       fi
    fi
    # Flush cloudfront cache for latest/index.html
    aws cloudfront create-invalidation --distribution-id $distid --path /components/$relpath/latest/index.html
fi
