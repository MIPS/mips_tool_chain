#!/bin/bash

JDK=${JDK:-/usr/java/jdk-11.0.2}

if [ -d $JDK ]; then
    PATH=$JDK/bin:$PATH
else
    echo "Error: JDK missing"
    exit
fi

DITA_HOME=${DITA_HOME:-/opt/dita-ot-2.4.4}

if [ ! -d $DITA_HOME ]; then
    echo "Error: Missing Dita installation"
    exit
fi

PATH=/opt/dita-ot-2.4.4/bin:$PATH

if [ -z $1 ]; then
    echo "No source directory specified"
    exit
fi

SRC=$1

for fn in $( find $SRC -name "bookmap*.ditamap" ); do
    logfile=`basename $fn`
    logfile=${logfile#bookmap-}
    logfile=${logfile%.ditamap}
    logfile="$logfile".log
    dita -i $fn -filter=$SRC/ditaval/nano_i7200only_gs.ditaval -f custpdf --args.fo.userconfig="plugins\com.imgtec.custpdf\cfg\fo\fop.xconf" -d -l $logfile
done
