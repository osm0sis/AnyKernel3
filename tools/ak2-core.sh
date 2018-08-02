## AnyKernel methods (DO NOT CHANGE)
# set up extracted files and directories
ramdisk=/tmp/anykernel/ramdisk;
bin=/tmp/anykernel/tools;
split_img=/tmp/anykernel/split_img;
patch=/tmp/anykernel/patch;

chmod -R 755 $bin;
mkdir -p $split_img;

FD=$1;
OUTFD=/proc/self/fd/$FD;

# ui_print <text>
ui_print() { echo -e "ui_print $1\nui_print" > $OUTFD; }

# contains <string> <substring>
contains() { test "${1#*$2}" != "$1" && return 0 || return 1; }

# file_getprop <file> <property>
file_getprop() { grep "^$2=" "$1" | cut -d= -f2; }

# reset anykernel directory
reset_ak() {
  local i;
  rm -rf $(dirname /tmp/anykernel/*-files/current)/ramdisk;
  for i in $ramdisk $split_img /tmp/anykernel/rdtmp /tmp/anykernel/boot.img /tmp/anykernel/*-new*; do
    cp -af $i $(dirname /tmp/anykernel/*-files/current);
  done;
  rm -rf $ramdisk $split_img $patch /tmp/anykernel/rdtmp /tmp/anykernel/boot.img /tmp/anykernel/*-new* /tmp/anykernel/*-files/current;
  . /tmp/anykernel/tools/ak2-core.sh $FD;
}

# dump boot and extract ramdisk
split_boot() {
  local nooktest nookoff dumpfail;
  if [ ! -e "$(echo $block | cut -d\  -f1)" ]; then
    ui_print " "; ui_print "Invalid partition. Aborting..."; exit 1;
  fi;
  if [ -f "$bin/nanddump" ]; then
    $bin/nanddump -f /tmp/anykernel/boot.img $block;
  else
    dd if=$block of=/tmp/anykernel/boot.img;
  fi;
  nooktest=$(strings /tmp/anykernel/boot.img | grep -E 'Red Loader|Green Loader|Green Recovery|eMMC boot.img|eMMC recovery.img|BauwksBoot');
  if [ "$nooktest" ]; then
    case $nooktest in
      *BauwksBoot*) nookoff=262144;;
      *) nookoff=1048576;;
    esac;
    mv -f /tmp/anykernel/boot.img /tmp/anykernel/boot-orig.img;
    dd bs=$nookoff count=1 conv=notrunc if=/tmp/anykernel/boot-orig.img of=$split_img/boot.img-master_boot.key;
    dd bs=$nookoff skip=1 conv=notrunc if=/tmp/anykernel/boot-orig.img of=/tmp/anykernel/boot.img;
  fi;
  if [ -f "$bin/unpackelf" -a "$($bin/unpackelf -i /tmp/anykernel/boot.img -h -q 2>/dev/null; echo $?)" == 0 ]; then
    if [ -f "$bin/elftool" ]; then
      mkdir $split_img/elftool_out;
      $bin/elftool unpack -i /tmp/anykernel/boot.img -o $split_img/elftool_out;
      cp -f $split_img/elftool_out/header $split_img/boot.img-header;
    fi;
    $bin/unpackelf -i /tmp/anykernel/boot.img -o $split_img;
    mv -f $split_img/boot.img-ramdisk.cpio.gz $split_img/boot.img-ramdisk.gz;
  elif [ -f "$bin/dumpimage" ]; then
    $bin/dumpimage -l /tmp/anykernel/boot.img;
    $bin/dumpimage -l /tmp/anykernel/boot.img > $split_img/boot.img-header;
    grep "Name:" $split_img/boot.img-header | cut -c15- > $split_img/boot.img-name;
    grep "Type:" $split_img/boot.img-header | cut -c15- | cut -d\  -f1 > $split_img/boot.img-arch;
    grep "Type:" $split_img/boot.img-header | cut -c15- | cut -d\  -f2 > $split_img/boot.img-os;
    grep "Type:" $split_img/boot.img-header | cut -c15- | cut -d\  -f3 | cut -d- -f1 > $split_img/boot.img-type;
    grep "Type:" $split_img/boot.img-header | cut -d\( -f2 | cut -d\) -f1 | cut -d\  -f1 | cut -d- -f1 > $split_img/boot.img-comp;
    grep "Address:" $split_img/boot.img-header | cut -c15- > $split_img/boot.img-addr;
    grep "Point:" $split_img/boot.img-header | cut -c15- > $split_img/boot.img-ep;
    $bin/dumpimage -i /tmp/anykernel/boot.img -p 0 $split_img/boot.img-zImage;
    test $? != 0 && dumpfail=1;
    if [ "$(cat $split_img/boot.img-type)" == "Multi" ]; then
      $bin/dumpimage -i /tmp/anykernel/boot.img -p 1 $split_img/boot.img-ramdisk.gz;
    fi;
    test $? != 0 && dumpfail=1;
  elif [ -f "$bin/rkcrc" ]; then
    dd bs=4096 skip=8 iflag=skip_bytes conv=notrunc if=/tmp/anykernel/boot.img of=$split_img/boot.img-ramdisk.gz;
  elif [ -f "$bin/pxa-unpackbootimg" ]; then
    $bin/pxa-unpackbootimg -i /tmp/anykernel/boot.img -o $split_img;
  else
    $bin/unpackbootimg -i /tmp/anykernel/boot.img -o $split_img;
  fi;
  if [ $? != 0 -o "$dumpfail" ]; then
    ui_print " "; ui_print "Dumping/splitting image failed. Aborting..."; exit 1;
  fi;
  if [ -f "$bin/unpackelf" -a -f "$split_img/boot.img-dtb" ]; then
    case $(od -ta -An -N4 $split_img/boot.img-dtb | sed -e 's/del //' -e 's/   //g') in
      QCDT|ELF) ;;
      *) gzip $split_img/boot.img-zImage;
         mv -f $split_img/boot.img-zImage.gz $split_img/boot.img-zImage;
         cat $split_img/boot.img-dtb >> $split_img/boot.img-zImage;
         rm -f $split_img/boot.img-dtb;;
    esac;
  fi;
}
unpack_ramdisk() {
  local compext unpackcmd;
  if [ -f "$bin/mkmtkhdr" ]; then
    dd bs=512 skip=1 conv=notrunc if=$split_img/boot.img-ramdisk.gz of=$split_img/temprd;
    mv -f $split_img/temprd $split_img/boot.img-ramdisk.gz;
  fi;
  mv -f $ramdisk /tmp/anykernel/rdtmp;
  case $(od -ta -An -N4 $split_img/boot.img-ramdisk.gz) in
    '  us  vt'*|'  us  rs'*) compext="gz"; unpackcmd="gzip";;
    '  ht   L   Z   O') compext="lzo"; unpackcmd="lzop";;
    '   ] nul nul nul') compext="lzma"; unpackcmd="$bin/xz";;
    '   }   7   z   X') compext="xz"; unpackcmd="$bin/xz";;
    '   B   Z   h'*) compext="bz2"; unpackcmd="bzip2";;
    ' stx   !   L can') compext="lz4-l"; unpackcmd="$bin/lz4";;
    ' etx   !   L can'|' eot   "   M can') compext="lz4"; unpackcmd="$bin/lz4";;
    *) ui_print " "; ui_print "Unknown ramdisk compression. Aborting..."; exit 1;;
  esac;
  mv -f $split_img/boot.img-ramdisk.gz $split_img/boot.img-ramdisk.cpio.$compext;
  mkdir -p $ramdisk;
  chmod 755 $ramdisk;
  cd $ramdisk;
  $unpackcmd -dc $split_img/boot.img-ramdisk.cpio.$compext | EXTRACT_UNSAFE_SYMLINKS=1 cpio -i -d;
  if [ $? != 0 -o -z "$(ls $ramdisk)" ]; then
    ui_print " "; ui_print "Unpacking ramdisk failed. Aborting..."; exit 1;
  fi;
  test ! -z "$(ls /tmp/anykernel/rdtmp)" && cp -af /tmp/anykernel/rdtmp/* $ramdisk;
}
dump_boot() {
  split_boot;
  unpack_ramdisk;
}

# repack ramdisk then build and write image
repack_ramdisk() {
  local compext repackcmd;
  case $ramdisk_compression in
    auto|"") compext=`echo $split_img/*-ramdisk.cpio.* | rev | cut -d. -f1 | rev`;;
    *) compext=$ramdisk_compression;;
  esac;
  case $compext in
    gz) repackcmd="gzip";;
    lzo) repackcmd="lzo";;
    lzma) repackcmd="$bin/xz -Flzma";;
    xz) repackcmd="$bin/xz -Ccrc32";;
    bz2) repackcmd="bzip2";;
    lz4-l) repackcmd="$bin/lz4 -l";;
    lz4) repackcmd="$bin/lz4";;
  esac;
  if [ -f "$bin/mkbootfs" ]; then
    $bin/mkbootfs $ramdisk | $repackcmd -9c > /tmp/anykernel/ramdisk-new.cpio.$compext;
  else
    cd $ramdisk;
    find . | cpio -H newc -o | $repackcmd -9c > /tmp/anykernel/ramdisk-new.cpio.$compext;
  fi;
  if [ $? != 0 ]; then
    ui_print " "; ui_print "Repacking ramdisk failed. Aborting..."; exit 1;
  fi;
  cd /tmp/anykernel;
  if [ -f "$bin/mkmtkhdr" ]; then
    $bin/mkmtkhdr --rootfs ramdisk-new.cpio.$compext;
    mv -f ramdisk-new.cpio.$compext-mtk ramdisk-new.cpio.$compext;
  fi;
}
flash_dtbo() {
  for i in dtbo dtbo.img; do
    if [ -f /tmp/anykernel/$i ]; then
      dtbo=$i;
      break;
    fi;
  done;
  if [ "$dtbo" ]; then
    dtbo_block=/dev/block/bootdevice/by-name/dtbo$slot;
    if [ ! -e "$(echo $dtbo_block)" ]; then
      ui_print " "; ui_print "dtbo partition could not be found. Aborting..."; exit 1;
    fi;
    if [ -f "$bin/flash_erase" -a -f "$bin/nandwrite" ]; then
      $bin/flash_erase $dtbo_block 0 0;
      $bin/nandwrite -p $dtbo_block /tmp/anykernel/$dtbo;
    else
      dd if=/dev/zero of=$dtbo_block 2>/dev/null;
      dd if=/tmp/anykernel/$dtbo of=$dtbo_block;
    fi;
  fi;
}
flash_boot() {
  local name arch os type comp addr ep cmdline cmd board base pagesize kerneloff ramdiskoff tagsoff osver oslvl second secondoff hash unknown i kernel rd dtb rpm pk8 cert avbtype dtbo dtbo_block;
  cd $split_img;
  if [ -f "$bin/mkimage" ]; then
    name=`cat *-name`;
    arch=`cat *-arch`;
    os=`cat *-os`;
    type=`cat *-type`;
    comp=`cat *-comp`;
    test "$comp" == "uncompressed" && comp=none;
    addr=`cat *-addr`;
    ep=`cat *-ep`;
  else
    if [ -f *-cmdline ]; then
      cmdline=`cat *-cmdline`;
      cmd="$split_img/boot.img-cmdline@cmdline";
    fi;
    if [ -f *-board ]; then
      board=`cat *-board`;
    fi;
    base=`cat *-base`;
    pagesize=`cat *-pagesize`;
    kerneloff=`cat *-kerneloff`;
    ramdiskoff=`cat *-ramdiskoff`;
    if [ -f *-tagsoff ]; then
      tagsoff=`cat *-tagsoff`;
    fi;
    if [ -f *-osversion ]; then
      osver=`cat *-osversion`;
    fi;
    if [ -f *-oslevel ]; then
      oslvl=`cat *-oslevel`;
    fi;
    if [ -f *-second ]; then
      second=`ls *-second`;
      second="--second $split_img/$second";
      secondoff=`cat *-secondoff`;
      secondoff="--second_offset $secondoff";
    fi;
    if [ -f *-hash ]; then
      hash=`cat *-hash`;
      test "$hash" == "unknown" && hash=sha1;
      hash="--hash $hash";
    fi;
    if [ -f *-unknown ]; then
      unknown=`cat *-unknown`;
    fi;
  fi;
  for i in zImage zImage-dtb Image.gz Image Image-dtb Image.gz-dtb Image.bz2 Image.bz2-dtb Image.lzo Image.lzo-dtb Image.lzma Image.lzma-dtb Image.xz Image.xz-dtb Image.lz4 Image.lz4-dtb Image.fit; do
    if [ -f /tmp/anykernel/$i ]; then
      kernel=/tmp/anykernel/$i;
      break;
    fi;
  done;
  if [ ! "$kernel" ]; then
    kernel=`ls *-zImage`;
    kernel=$split_img/$kernel;
  fi;
  if [ -f /tmp/anykernel/ramdisk-new.cpio.* ]; then
    rd=`echo /tmp/anykernel/ramdisk-new.cpio.*`;
  else
    rd=`ls *-ramdisk.*`;
    rd="$split_img/$rd";
  fi;
  for i in dtb dt.img; do
    if [ -f /tmp/anykernel/$i ]; then
      dtb="--dt /tmp/anykernel/$i";
      rpm="/tmp/anykernel/$i,rpm";
      break;
    fi;
  done;
  if [ ! "$dtb" -a -f *-dtb ]; then
    dtb=`ls *-dtb`;
    rpm="$split_img/$dtb,rpm";
    dtb="--dt $split_img/$dtb";
  fi;
  cd /tmp/anykernel;
  if [ -f "$bin/mkmtkhdr" ]; then
    case $kernel in
      $split_img/*) ;;
      *) $bin/mkmtkhdr --kernel $kernel; kernel=$kernel-mtk;;
    esac;
  fi;
  if [ -f "$bin/mkimage" ]; then
    test "$type" == "Multi" && uramdisk=":$rd";
    $bin/mkimage -A $arch -O $os -T $type -C $comp -a $addr -e $ep -n "$name" -d $kernel$uramdisk boot-new.img;
  elif [ -f "$bin/elftool" ]; then
    $bin/elftool pack -o boot-new.img header=$split_img/boot.img-header $kernel $rd,ramdisk $rpm $cmd;
  elif [ -f "$bin/rkcrc" ]; then
    $bin/rkcrc -k $rd boot-new.img;
  elif [ -f "$bin/pxa-mkbootimg" ]; then
    $bin/pxa-mkbootimg --kernel $kernel --ramdisk $rd $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff $secondoff --tags_offset "$tagsoff" --unknown $unknown $dtb --output boot-new.img;
  else
    $bin/mkbootimg --kernel $kernel --ramdisk $rd $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff $secondoff --tags_offset "$tagsoff" --os_version "$osver" --os_patch_level "$oslvl" $hash $dtb --output boot-new.img;
  fi;
  if [ $? != 0 ]; then
    ui_print " "; ui_print "Repacking image failed. Aborting..."; exit 1;
  fi;
  if [ -f "$bin/futility" -a -d "$bin/chromeos" ]; then
    $bin/futility vbutil_kernel --pack boot-new-signed.img --keyblock $bin/chromeos/kernel.keyblock --signprivate $bin/chromeos/kernel_data_key.vbprivk --version 1 --vmlinuz boot-new.img --bootloader $bin/chromeos/empty --config $bin/chromeos/empty --arch arm --flags 0x1;
    if [ $? != 0 ]; then
      ui_print " "; ui_print "Signing image failed. Aborting..."; exit 1;
    fi;
    mv -f boot-new-signed.img boot-new.img;
  fi;
  if [ -f "$bin/BootSignature_Android.jar" -a -d "$bin/avb" ]; then
    pk8=`ls $bin/avb/*.pk8`;
    cert=`ls $bin/avb/*.x509.*`;
    case $block in
      *recovery*|*SOS*) avbtype=recovery;;
      *) avbtype=boot;;
    esac;
    if [ "$(/system/bin/dalvikvm -Xbootclasspath:/system/framework/core-oj.jar:/system/framework/core-libart.jar:/system/framework/conscrypt.jar:/system/framework/bouncycastle.jar -Xnodex2oat -Xnoimage-dex2oat -cp $bin/BootSignature_Android.jar com.android.verity.BootSignature -verify boot.img 2>&1 | grep VALID)" ]; then
      /system/bin/dalvikvm -Xbootclasspath:/system/framework/core-oj.jar:/system/framework/core-libart.jar:/system/framework/conscrypt.jar:/system/framework/bouncycastle.jar -Xnodex2oat -Xnoimage-dex2oat -cp $bin/BootSignature_Android.jar com.android.verity.BootSignature /$avbtype boot-new.img $pk8 $cert boot-new-signed.img;
      if [ $? != 0 ]; then
        ui_print " "; ui_print "Signing image failed. Aborting..."; exit 1;
      fi;
    fi;
    mv -f boot-new-signed.img boot-new.img;
  fi;
  if [ -f "$bin/blobpack" ]; then
    printf '-SIGNED-BY-SIGNBLOB-\00\00\00\00\00\00\00\00' > boot-new-signed.img;
    $bin/blobpack tempblob LNX boot-new.img;
    cat tempblob >> boot-new-signed.img;
    mv -f boot-new-signed.img boot-new.img;
  fi;
  if [ -f "/data/custom_boot_image_patch.sh" ]; then
    ash /data/custom_boot_image_patch.sh /tmp/anykernel/boot-new.img;
    if [ $? != 0 ]; then
      ui_print " "; ui_print "User script execution failed. Aborting..."; exit 1;
    fi;
  fi;
  if [ "$(strings /tmp/anykernel/boot.img | grep SEANDROIDENFORCE )" ]; then
    printf 'SEANDROIDENFORCE' >> boot-new.img;
  fi;
  if [ -f "$bin/dhtbsign" ]; then
    $bin/dhtbsign -i boot-new.img -o boot-new-signed.img;
    mv -f boot-new-signed.img boot-new.img;
  fi;
  if [ -f "$split_img/boot.img-master_boot.key" ]; then
    cat $split_img/boot.img-master_boot.key boot-new.img > boot-new-signed.img;
    mv -f boot-new-signed.img boot-new.img;
  fi;
  if [ ! -f /tmp/anykernel/boot-new.img ]; then
    ui_print " "; ui_print "Repacked image could not be found. Aborting..."; exit 1;
  elif [ "$(wc -c < boot-new.img)" -gt "$(wc -c < boot.img)" ]; then
    ui_print " "; ui_print "New image larger than boot partition. Aborting..."; exit 1;
  fi;
  if [ -f "$bin/flash_erase" -a -f "$bin/nandwrite" ]; then
    $bin/flash_erase $block 0 0;
    $bin/nandwrite -p $block /tmp/anykernel/boot-new.img;
  else
    dd if=/dev/zero of=$block 2>/dev/null;
    dd if=/tmp/anykernel/boot-new.img of=$block;
  fi;
}
write_boot() {
  repack_ramdisk;
  flash_boot;
  flash_dtbo;
}

# backup_file <file>
backup_file() { test ! -f $1~ && cp $1 $1~; }

# restore_file <file>
restore_file() { test -f $1~ && mv -f $1~ $1; }

# replace_string <file> <if search string> <original string> <replacement string>
replace_string() {
  if [ -z "$(grep "$2" $1)" ]; then
    sed -i "s;${3};${4};" $1;
  fi;
}

# replace_section <file> <begin search string> <end search string> <replacement string>
replace_section() {
  local begin endstr last end;
  begin=`grep -n "$2" $1 | head -n1 | cut -d: -f1`;
  if [ "$begin" ]; then
    if [ "$3" == " " -o -z "$3" ]; then
      endstr='^[[:space:]]*$';
      last=$(wc -l $1 | cut -d\  -f1);
    else
      endstr="$3";
    fi;
    for end in $(grep -n "$endstr" $1 | cut -d: -f1) $last; do
      if [ "$end" ] && [ "$begin" -lt "$end" ]; then
        sed -i "${begin},${end}d" $1;
        test "$end" == "$last" && echo >> $1;
        sed -i "${begin}s;^;${4}\n;" $1;
        break;
      fi;
    done;
  fi;
}

# remove_section <file> <begin search string> <end search string>
remove_section() {
  local begin endstr last end;
  begin=`grep -n "$2" $1 | head -n1 | cut -d: -f1`;
  if [ "$begin" ]; then
    if [ "$3" == " " -o -z "$3" ]; then
      endstr='^[[:space:]]*$';
      last=$(wc -l $1 | cut -d\  -f1);
    else
      endstr="$3";
    fi;
    for end in $(grep -n "$endstr" $1 | cut -d: -f1) $last; do
      if [ "$end" ] && [ "$begin" -lt "$end" ]; then
        sed -i "${begin},${end}d" $1;
        break;
      fi;
    done;
  fi;
}

# insert_line <file> <if search string> <before|after> <line match string> <inserted line>
insert_line() {
  local offset line;
  if [ -z "$(grep "$2" $1)" ]; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | head -n1 | cut -d: -f1` + offset));
    if [ -f $1 -a "$line" ] && [ "$(wc -l $1 | cut -d\  -f1)" -lt "$line" ]; then
      echo "$5" >> $1;
    else
      sed -i "${line}s;^;${5}\n;" $1;
    fi;
  fi;
}

# replace_line <file> <line replace string> <replacement line>
replace_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    local line=`grep -n "$2" $1 | head -n1 | cut -d: -f1`;
    sed -i "${line}s;.*;${3};" $1;
  fi;
}

# remove_line <file> <line match string>
remove_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    local line=`grep -n "$2" $1 | head -n1 | cut -d: -f1`;
    sed -i "${line}d" $1;
  fi;
}

# prepend_file <file> <if search string> <patch file>
prepend_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo "$(cat $patch/$3 $1)" > $1;
  fi;
}

# insert_file <file> <if search string> <before|after> <line match string> <patch file>
insert_file() {
  local offset line;
  if [ -z "$(grep "$2" $1)" ]; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | head -n1 | cut -d: -f1` + offset));
    sed -i "${line}s;^;\n;" $1;
    sed -i "$((line - 1))r $patch/$5" $1;
  fi;
}

# append_file <file> <if search string> <patch file>
append_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo -ne "\n" >> $1;
    cat $patch/$3 >> $1;
    echo -ne "\n" >> $1;
  fi;
}

# replace_file <file> <permissions> <patch file>
replace_file() {
  cp -pf $patch/$3 $1;
  chmod $2 $1;
}

# patch_fstab <fstab file> <mount match name> <fs match type> <block|mount|fstype|options|flags> <original string> <replacement string>
patch_fstab() {
  local entry part newpart newentry;
  entry=$(grep "$2" $1 | grep "$3");
  if [ -z "$(echo "$entry" | grep "$6")" -o "$6" == " " -o -z "$6" ]; then
    case $4 in
      block) part=$(echo "$entry" | awk '{ print $1 }');;
      mount) part=$(echo "$entry" | awk '{ print $2 }');;
      fstype) part=$(echo "$entry" | awk '{ print $3 }');;
      options) part=$(echo "$entry" | awk '{ print $4 }');;
      flags) part=$(echo "$entry" | awk '{ print $5 }');;
    esac;
    newpart=$(echo "$part" | sed -e "s;${5};${6};" -e "s; ;;g" -e 's;,\{2,\};,;g' -e 's;,*$;;g' -e 's;^,;;g');
    newentry=$(echo "$entry" | sed "s;${part};${newpart};");
    sed -i "s;${entry};${newentry};" $1;
  fi;
}

# patch_cmdline <cmdline entry name> <replacement string>
patch_cmdline() {
  local cmdfile cmdtmp match;
  cmdfile=`ls $split_img/*-cmdline`;
  if [ -z "$(grep "$1" $cmdfile)" ]; then
    cmdtmp=`cat $cmdfile`;
    echo "$cmdtmp $2" > $cmdfile;
    sed -i -e 's;  *; ;g' -e 's;[ \t]*$;;' $cmdfile;
  else
    match=$(grep -o "$1.*$" $cmdfile | cut -d\  -f1);
    sed -i -e "s;${match};${2};" -e 's;  *; ;g' -e 's;[ \t]*$;;' $cmdfile;
  fi;
}

# patch_prop <prop file> <prop name> <new prop value>
patch_prop() {
  if [ -z "$(grep "^$2=" $1)" ]; then
    echo -ne "\n$2=$3\n" >> $1;
  else
    local line=`grep -n "^$2=" $1 | head -n1 | cut -d: -f1`;
    sed -i "${line}s;.*;${2}=${3};" $1;
  fi;
}

# patch_ueventd <ueventd file> <device node> <permissions> <chown> <chgrp>
patch_ueventd() {
  local file dev perm user group newentry line;
  file=$1; dev=$2; perm=$3; user=$4;
  shift 4;
  group="$@";
  newentry=$(printf "%-23s   %-4s   %-8s   %s\n" "$dev" "$perm" "$user" "$group");
  line=`grep -n "$dev" $file | head -n1 | cut -d: -f1`;
  if [ "$line" ]; then
    sed -i "${line}s;.*;${newentry};" $file;
  else
    echo -ne "\n$newentry\n" >> $file;
  fi;
}

# allow multi-partition ramdisk modifying configurations (using reset_ak)
if [ ! -d "$ramdisk" -a ! -d "$patch" ]; then
  if [ -d "$(basename $block)-files" ]; then
    cp -af /tmp/anykernel/$(basename $block)-files/* /tmp/anykernel;
  else
    mkdir -p /tmp/anykernel/$(basename $block)-files;
  fi;
  touch /tmp/anykernel/$(basename $block)-files/current;
fi;
test ! -d "$ramdisk" && mkdir -p $ramdisk;

# slot detection enabled by is_slot_device=1 or auto (from anykernel.sh)
case $is_slot_device in
  1|auto)
    slot=$(getprop ro.boot.slot_suffix 2>/dev/null);
    test ! "$slot" && slot=$(grep -o 'androidboot.slot_suffix=.*$' /proc/cmdline | cut -d\  -f1 | cut -d= -f2);
    if [ ! "$slot" ]; then
      slot=$(getprop ro.boot.slot 2>/dev/null);
      test ! "$slot" && slot=$(grep -o 'androidboot.slot=.*$' /proc/cmdline | cut -d\  -f1 | cut -d= -f2);
      test "$slot" && slot=_$slot;
    fi;
    if [ ! "$slot" -a "$is_slot_device" == 1 ]; then
      ui_print " "; ui_print "Unable to determine active boot slot. Aborting..."; exit 1;
    fi;
  ;;
esac;

# target block partition detection enabled by block=boot recovery or auto (from anykernel.sh)
test "$block" == "auto" && block=boot;
case $block in
  boot|recovery)
    case $block in
      boot) parttype="ramdisk boot BOOT LNX android_boot KERN-A kernel KERNEL";;
      recovery) parttype="ramdisk_recovey recovery RECOVERY SOS android_recovery";;
    esac;
    for name in $parttype; do
      for part in $name $name$slot; do
        if [ "$(grep -w "$part" /proc/mtd 2> /dev/null)" ]; then
          mtdmount=$(grep -w "$part" /proc/mtd);
          mtdpart=$(echo $mtdmount | cut -d\" -f2);
          if [ "$mtdpart" == "$part" ]; then
            mtd=$(echo $mtdmount | cut -d: -f1);
          else
            ui_print " "; ui_print "Unable to determine mtd $block partition. Aborting..."; exit 1;
          fi;
          target=/dev/mtd/$mtd;
        elif [ -e /dev/block/bootdevice/by-name/$part ]; then
          target=/dev/block/bootdevice/by-name/$part;
        elif [ -e /dev/block/platform/*/by-name/$part ]; then
          target=/dev/block/platform/*/by-name/$part;
        elif [ -e /dev/block/platform/*/*/by-name/$part ]; then
          target=/dev/block/platform/*/*/by-name/$part;
        fi;
        test -e "$target" && break 2;
      done;
    done;
    if [ "$target" ]; then
      block=$(echo -n $target);
    else
      ui_print " "; ui_print "Unable to determine $block partition. Aborting..."; exit 1;
    fi;
  ;;
  *)
    if [ "$slot" ]; then
      test -e "$block$slot" && block=$block$slot;
    fi;
  ;;
esac;

## end methods

