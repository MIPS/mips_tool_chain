#!/bin/bash

tmp=`mktemp`

if [ $? != 0 ]
then
  echo 'Unable to create temporary directory'
  exit 1
fi

tmp2=`mktemp`

if [ $? != 0 ]
then
  echo 'Unable to create temporary directory'
  exit 1
fi


files=`find $@ -name log.gcc.log.gz`

for f in $files
do
  echo Processing $f ... >&1
  gunzip -d --stdout $f > $tmp2
  target=`grep '^Target is' $tmp2 | cut -f3 -d' '`
  config=`grep '^Running target' $tmp2 | cut -f3- -d' ' | sed 's%\/%\\\/%g'`
  # We don't care about single-float short-double for the moment
  sf=`echo $config | grep short-double`
  if [ "$sf" == "" ]
  then
    # We have to do a tr conversion here so that we remove the spaces from the string
    # so that the for statement will correctly iterate over the testsuite names
    for fail in `grep -h ^FAIL $tmp2 | tr ' ' '^'`
    do
      testname=`echo $fail | cut -f2 -d'^'`
      lto=`echo $fail | grep FAIL.*-flto`
      # Don't worry about LTO failures for the moment.
      if [ "$lto" == "" ]
      then
        echo $testname $target $config $f >> $tmp
      else
        echo Ignore LTO test failure $testname $target $config
      fi
    done
  else
    echo Skipping single-float short-double failure $f [$config]
  fi
done

sort $tmp | uniq -c | tr -s ' ' | awk 'BEGIN {test=""; FS=" "; OFS="\t\t"} { if ($2 != test) { test=$2; print "\n\n"; print test,"\n-------------" } print $3,$4,$5,$1 }'

rm $tmp
rm $tmp2
