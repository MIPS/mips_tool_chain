local_patch=1

function update_gcc_toolchain() {
  local home="$1"
  local target="$2"
  local output_file="$3"
  local args="--local --git_home=$GITHOME"
  local pkgs="packages binutils expat gdb gcc bison glibc newlib zlib pixman glib qemu gmp mpfr mpc dejagnu"
  cd $home
  if [ "$GITREF" != "" ]; then
      args="$args --git_ref=$GITREF"
  fi
  if [ "$output_file" != "" ] ; then
    (cd src/mips_tool_chain; git pull) > $output_file 2>&1
    ret=$?
  else
    (cd src/mips_tool_chain; git pull)
    ret=$?
  fi
  if [ $ret -ne 0 ] ; then
    echo "UPDATE of build tools failed"
  fi
  if [ "$output_file" != "" ] ; then
    b/build_toolchain update $args $pkgs >> $output_file 2>&1
    ret=$?
  else
    b/build_toolchain update $args $pkgs
    ret=$?
  fi
  if [ $ret -ne 0 ] ; then
    echo "UPDATE failed"
  fi
  return $ret
}

applied_patches=()
failed_patches=()

function update_patch_gcc_toolchain() {
  local home="$1"
  local target="$2"
  local output_file="$3"
  local args="--local --git_home=$GITHOME"
  local pkgs="packages binutils expat gdb  gmp mpfr mpc gcc glibc newlib zlib pixman glib qemu dejagnu"
  local src="$home"/src
  local patches="$src"/patches

  if [ $local_patch -eq 1 ]; then
      for i in $pkgs; do
	  if [ -d $src/$i/.git ]; then
	      cd $src/$i && git clean -fq && git prune && git checkout -- .
	  fi
      done
  fi

  update_gcc_toolchain  $home $target $output_file

  if [ $local_patch -eq 1 ]; then
      for i in $pkgs; do
	  if [ ! -f $patches/"$i".list ]; then
	      continue
	  fi

	  for p in $( cat $patches/"$i".list ); do
	      cd $src/$i && patch -p1 -s --dry-run -r - < ../patches/"$p".patch
	      if [ $? -eq 0 ]; then
		  cd $src/$i && patch -p1 -s < ../patches/"$p".patch
		  applied_patches+=("$i:$p")
	      else
		  failed_patches+=("$i:$p")
	      fi
	  done
      done
  fi
  cd $home
}

function build_gcc_toolchain() {
  local home="$1"
  local target="$2"
  local output_file="$3"
  local host_install=$home/install-host
  local install=$home/install-$target
  local obj=$home/obj-$target
  local args="--local --git_home=$GITHOME --build=$obj --jobs=$JOBS"
  args="$args --path=$host_install/bin"
  local host_args="--prefix=$host_install"
  local target_args="--prefix=$install --target=$target --path=$install/bin"
  local target_args="$target_args --hostlibs=$host_install"
  source /opt/rh/devtoolset-7/enable

  case "$target" in
    *linux*) host_components="expat zlib pixman glib bison"
	     target_components="binutils initial_gcc linux_headers sysroot gcc"
	     target_components="$target_components gdb qemu"
             target_args="$target_args --sysroot=$install/sysroot"
	     target_args="$target_args --languages=c,c++,fortran"
	     args="$args:/opt/rh/rh-python36/root/usr/bin"
             ;;
    *elf*)   host_components="expat"
	     target_components="binutils gcc gdb"
             target_args="$target_args --sysroot=$install/$target"
             ;;
  esac
  case "$MNAME" in
    mipsswvm001) args="$args --32bit-build"
		 ;;
  esac

  cd $home
  /bin/rm -rf $host_install $install $obj

  if [ "$output_file" != "" ] ; then
    b/build_toolchain build $host_args $args $host_components > $output_file 2>&1
    b/build_toolchain build $target_args $args $target_components >> $output_file 2>&1
    ret=$?
  else
    b/build_toolchain build $host_args $args $host_components
    b/build_toolchain build $target_args $args $target_components
    ret=$?
  fi

  if [ $ret -eq 0 ] ; then
    echo "BUILD of $target successful"
  else
    echo "BUILD of $target failed"
  fi
  return $ret
}

function check_gcc_toolchain() {
  local home="$1"
  local target="$2"
  local output_file="$3"
  local install=$home/install-$target
  local obj=$home/obj-$target
  local args="--local --git_home=$GITHOME --path=$home/bin --build=$obj --prefix=$install --target=$target --jobs=$JOBS"
  cd $home
  # Only do tests if build succeeded.
  if [ -x $install/bin/$target-gcc ] ; then
    case $target in
      *linux*)
	b/build_toolchain check $args --dejagnu_sim=$install/bin/qemu-mips --dejagnu_sim_options='-r 4.0' --runtestflags='--target_board=multi-sim' gcc > $output_file 2>&1
	;;
      *elf)
	b/build_toolchain check $args --runtestflags="--target_board='mips-sim-mti32'" gcc > $output_file 2>&1
	;;
    esac
    ret=$?
    if [ $ret -ne 0 ] ; then
      echo "TEST of $target failed"
    fi
  else
    echo "TEST of $target not done because no compiler exists"
    ret=0
  fi
  return $ret
}

function report_gcc_failures() {
  local home="$1"
  local target="$2"
  local output_file="$3"

  if [ -f $output_file ] ; then
    echo
    echo "=========== Test Results for $target ============"
    grep -e '^XPASS' -e '^FAIL' $output_file | sort
  fi
}

function save_gcc_failures() {
  local home="$1"
  local target="$2"
  local output_file="$3"
  local dest="$4"

  if [ -f $output_file ] ; then
    echo "# $GCC_COMMIT_HASH" > $dest
    grep -e '^XPASS' -e '^FAIL' $output_file | sort >> $dest
    echo "SAVE $target toolchain failure list in $dest"
  else
    echo "SAVE of $target toolchain failure list in $dest FAILED"
  fi
}

function copy_gcc_toolchain() {
  local home="$1"
  local target="$2"
  local dest="$3"
  local install=$home/install-$target

if [ "$USER" = "buildbot" ]; then
  mkdir -p $dest
  if [ -d $dest ] ; then
    if [ -x $install/bin/$target-gcc ] ; then
      if [ -d $dest/install-$target ] ; then
	echo "COPY of $install not done because $dest/install-$target already exists."
      else
	cp -R $install $dest
	if [ $? -ne 0 ] ; then
	  echo "COPY of $install failed for unknown reason"
	else
	  echo "COPY $target toolchain from $install to $dest"
	fi
      fi
    else
      echo "COPY of $install not done because no compiler found"
    fi
  else
    echo "COPY of $install failed due to no destination directory ($dest)"
  fi
fi
}

function list_gcc_repo_summary() {
  local home="$1"

  echo "========== GIT versions for src directories =========="
  cd $home
  for i in src/*
  do
    if [ -d $i/.git ] ; then
      branch=`(cd $i; git symbolic-ref HEAD)`
      hash=`(cd $i; git log -n 1 --format=%H)`
      echo "$i: $branch $hash"
    fi
  done
  echo
}

function list_gcc_local_changes() {
  echo
  echo "========== local changes to src directories =========="
  for i in src/*
  do
    if [ -d $i/.git ] ; then
      echo "---- src/$i ----"
      (cd $i; git diff origin) > /tmp/difflist 2>&1
      l=`wc -l /tmp/difflist | awk '{print $1}'`
      if [ $l -lt 100 ] ; then
	cat /tmp/difflist
      else
	echo "TOO MANY DIFFS TO LIST"
      fi
    fi
  done
}

function list_gcc_patch_summary() {
  local home="$1"
  anyfail=$2

  echo
  echo "========== Local patch summary for src directories =========="
  if [ ${#applied_patches[*]} -ne 0 ]; then
      echo "==== Applied patches ===="
      for patch in "${applied_patches[@]}"; do
	  echo "${patch/:/: }"
      done
      echo
  fi
  if [ ${#failed_patches[*]} -ne 0 ]; then
      echo "==== Failed/Redundant patches ===="
      for patch in "${failed_patches[@]}"; do
	  echo "${patch/:/: }"
      done
      echo
  fi
  echo
}

TOPDIR=$1
OVERRIDE_TARGET=$2
MNAME=`hostname -s`

# binutils 'make pdf-bfd' now needs LC_ALL=C
export LC_ALL=C

if [ "$USER" = "buildbot" ]; then
    EMAILS="fshahbazker@wavecomp.com"
    GITHOME="https://github.com/MIPS"
else
    EMAILS=`/usr/bin/adquery user $USER -M`"@mips.com"
    GITHOME="ssh://git@github.com/MIPS"
fi

case $MNAME in
  ubuntu-"$USER")
    JOBS=5
    GITHOME="file:///scratch/$USER/git"
    ;;
  mipsswvm001)
    JOBS=10
    EMAILSUB="nightly 32-bit"
    ;;
  mips-compiler-bld001)
    JOBS=40
    EMAILSUB="nightly 64-bit"
    GITREF="/scratch/overtest/git"
    renice -n15 $BASHPID
    ;;
  *)
    echo "No defaults for machine $MNAME"
    exit
    ;;
esac

if [ "$TOPDIR" = "" ] ; then
  echo "No $TOPDIR argument specified"
  exit
fi
if [ ! -d $TOPDIR ] ; then
  echo "$TOPDIR is not a directory"
  exit
fi
cd $TOPDIR

DIRNAME=`date +'log.%Y-%m-%d'`
SAVEDIR=/mips/proj/build-compiler/$DIRNAME
DATE=`date +"%F"`
if [ ! -d $HOME/failures ]; then
    mkdir $HOME/failures
fi
FAILDIR=$HOME/failures/$DATE

if [ "$OVERRIDE_TARGET" != "" ] ; then
	update_patch_gcc_toolchain $TOPDIR $OVERRIDE_TARGET ""
	build_gcc_toolchain $TOPDIR $OVERRIDE_TARGET ""
	anyfail=$?
	list_gcc_patch_summary $TOPDIR $anyfail
	exit
fi

(
echo "Nightly GCC build/run on $MNAME ($TOPDIR)"
echo

update_patch_gcc_toolchain $TOPDIR mips-mti-linux-gnu $TOPDIR/out.update
GCC_COMMIT_HASH=`(cd $TOPDIR/src/gcc; git log -n 1 --format=%H)`

anyfail=0
retml=0
retme=0
retil=0
case $MNAME in
  ubuntu-"$USER")
    /bin/rm -rf $TOPDIR/out.build.* $TOPDIR/out.check.*
    build_gcc_toolchain $TOPDIR mips-mti-linux-gnu $TOPDIR/out.build.mti.linux
    retl=$?
    build_gcc_toolchain $TOPDIR mips-mti-elf $TOPDIR/out.build.mti.elf
    rete=$?
    if [ $retl -eq 0 ] ; then
      check_gcc_toolchain $TOPDIR mips-mti-linux-gnu $TOPDIR/out.check.mti.linux
      report_gcc_failures $TOPDIR mips-mti-linux-gnu $TOPDIR/out.check.mti.linux
    fi
    if [ $rete -eq 0 ] ; then
      check_gcc_toolchain $TOPDIR mips-mti-elf $TOPDIR/out.check.mti.elf
      report_gcc_failures $TOPDIR mips-mti-elf $TOPDIR/out.check.mti.elf
    fi
    test $retl -ne 0 -o $rete -ne 0
    anyfail=$?
    ;;
  mipsswvm001|mips-compiler-bld001)
    build_gcc_toolchain $TOPDIR mips-mti-linux-gnu $TOPDIR/out.build.mti.linux
    retml=$?
    build_gcc_toolchain $TOPDIR mips-mti-elf $TOPDIR/out.build.mti.elf
    retme=$?
    build_gcc_toolchain $TOPDIR mips-img-linux-gnu $TOPDIR/out.build.img.linux
    retil=$?
    #build_gcc_toolchain $TOPDIR mips-img-elf $TOPDIR/out.build.img.elf
    #retie=$?
    if [ $retml -eq 0 ] ; then
      check_gcc_toolchain $TOPDIR mips-mti-linux-gnu $TOPDIR/out.check.mti.linux
      report_gcc_failures $TOPDIR mips-mti-linux-gnu $TOPDIR/out.check.mti.linux
      copy_gcc_toolchain  $TOPDIR mips-mti-linux-gnu $SAVEDIR
      save_gcc_failures   $TOPDIR mips-mti-linux-gnu $TOPDIR/out.check.mti.linux $FAILDIR.mips-mti-linux-gnu
    fi
    if [ $retme -eq 0 ] ; then
      # Work around broken GNU sim build.
      if [ -f $TOPDIR/run_bin/mips-mti-elf-run ] ; then
	echo ======================= Assuming mips-mti-elf-run is broken.
	echo ======================= Replacing it in the install bin directory.
	cp -p $TOPDIR/run_bin/mips-mti-elf-run $TOPDIR/install-mips-mti-elf/bin/.
      fi
      check_gcc_toolchain $TOPDIR mips-mti-elf $TOPDIR/out.check.mti.elf
      report_gcc_failures $TOPDIR mips-mti-elf $TOPDIR/out.check.mti.elf
      copy_gcc_toolchain  $TOPDIR mips-mti-elf $SAVEDIR
      save_gcc_failures   $TOPDIR mips-mti-elf $TOPDIR/out.check.mti.elf $FAILDIR.mips-mti-elf
    fi
    if [ $retil -eq 0 ] ; then
#     check_gcc_toolchain $TOPDIR mips-img-linux-gnu $TOPDIR/out.check.img.linux
#     report_gcc_failures $TOPDIR mips-img-linux-gnu $TOPDIR/out.check.img.linux
      copy_gcc_toolchain  $TOPDIR mips-img-linux-gnu $SAVEDIR
#     save_gcc_failures   $TOPDIR mips-img-linux-gnu $TOPDIR/out.check.img.linux $FAILDIR.mips-img-linux-gnu
    fi
#   if [ $retil -eq 0 ] ; then
#     check_gcc_toolchain $TOPDIR mips-img-linux-gnu $TOPDIR/out.check.img.linux
#     report_gcc_failures $TOPDIR mips-img-linux-gnu $TOPDIR/out.check.img.linux
#     copy_gcc_toolchain  $TOPDIR mips-img-linux-gnu $SAVEDIR
#     save_gcc_failures   $TOPDIR mips-img-linux-gnu $TOPDIR/out.check.img.linux $FAILDIR.mips-img-linux-gnu
#    fi
    test $retml -eq 0 -a $retme -eq 0 -a $retil -eq 0
    anyfail=$?
    ;;
esac

list_gcc_repo_summary $TOPDIR
if [ $local_patch -eq 0 ]; then
    list_gcc_local_changes $TOPDIR
else
    list_gcc_patch_summary $TOPDIR $anyfail
fi

) > $TOPDIR/cron 2>&1

cat $TOPDIR/cron | mailx -r "no-reply mips-compiler-bld001 <compiler_team_notifications@wavecomp.com>" -s "$EMAILSUB ($TOPDIR)" $EMAILS
