### AnyKernel methods (DO NOT CHANGE)
## osm0sis @ xda-developers

[ "$OUTFD" ] || OUTFD=$1;

# set up working directory variables
[ "$AKHOME" ] && home=$AKHOME;
[ "$home" ] || home=$PWD;
bootimg=$home/boot.img;
bin=$home/tools;
patch=$home/patch;
ramdisk=$home/ramdisk;
split_img=$home/split_img;

### output/testing functions:
# ui_print "<text>" [...]
ui_print() {
  until [ ! "$1" ]; do
    echo "ui_print $1
      ui_print" >> /proc/self/fd/$OUTFD;
    shift;
  done;
}

# abort ["<text>" [...]]
abort() {
  ui_print " " "$@";
  exit 1;
}

# contains <string> <substring>
contains() {
  [ "${1#*$2}" != "$1" ];
}

# file_getprop <file> <property>
file_getprop() {
  grep "^$2=" "$1" | tail -n1 | cut -d= -f2-;
}
###

### file/directory attributes functions:
# set_perm <owner> <group> <mode> <file> [<file2> ...]
set_perm() {
  local uid gid mod;
  uid=$1; gid=$2; mod=$3;
  shift 3;
  chown $uid:$gid "$@" || chown $uid.$gid "$@";
  chmod $mod "$@";
}

# set_perm_recursive <owner> <group> <dir_mode> <file_mode> <dir> [<dir2> ...]
set_perm_recursive() {
  local uid gid dmod fmod;
  uid=$1; gid=$2; dmod=$3; fmod=$4;
  shift 4;
  while [ "$1" ]; do
    chown -R $uid:$gid "$1" || chown -R $uid.$gid "$1";
    find "$1" -type d -exec chmod $dmod {} +;
    find "$1" -type f -exec chmod $fmod {} +;
    shift;
  done;
}
###

### dump_boot functions:
# split_boot (dump and split image only)
split_boot() {
  local dumpfail;

  if [ ! -e "$(echo $block | cut -d\  -f1)" ]; then
    abort "Invalid partition. Aborting...";
  fi;
  if [ "$(echo $block | grep ' ')" ]; then
    block=$(echo $block | cut -d\  -f1);
    customdd=$(echo $block | cut -d\  -f2-);
  elif [ ! "$customdd" ]; then
    local customdd="bs=1048576";
  fi;
  if [ -f "$bin/nanddump" ]; then
    $bin/nanddump -f $bootimg $block;
  else
    dd if=$block of=$bootimg $customdd;
  fi;
  [ $? != 0 ] && dumpfail=1;

  mkdir -p $split_img;
  cd $split_img;
  if [ -f "$bin/unpackelf" ] && $bin/unpackelf -i $bootimg -h -q 2>/dev/null; then
    if [ -f "$bin/elftool" ]; then
      mkdir elftool_out;
      $bin/elftool unpack -i $bootimg -o elftool_out;
    fi;
    $bin/unpackelf -i $bootimg;
    [ $? != 0 ] && dumpfail=1;
    mv -f boot.img-kernel kernel.gz;
    mv -f boot.img-ramdisk ramdisk.cpio.gz;
    mv -f boot.img-cmdline cmdline.txt 2>/dev/null;
    if [ -f boot.img-dt -a ! -f "$bin/elftool" ]; then
      case $(od -ta -An -N4 boot.img-dt | sed -e 's/ del//' -e 's/   //g') in
        QCDT|ELF) mv -f boot.img-dt dt;;
        *)
          gzip -c kernel.gz > kernel.gz-dtb;
          cat boot.img-dt >> kernel.gz-dtb;
          rm -f boot.img-dt kernel.gz;
        ;;
      esac;
    fi;
  elif [ -f "$bin/mboot" ]; then
    $bin/mboot -u -f $bootimg;
  elif [ -f "$bin/dumpimage" ]; then
    dd bs=$(($(printf '%d\n' 0x$(hexdump -n 4 -s 12 -e '16/1 "%02x""\n"' $bootimg)) + 64)) count=1 conv=notrunc if=$bootimg of=boot-trimmed.img;
    $bin/dumpimage -l boot-trimmed.img > header;
    grep "Name:" header | cut -c15- > boot.img-name;
    grep "Type:" header | cut -c15- | cut -d\  -f1 > boot.img-arch;
    grep "Type:" header | cut -c15- | cut -d\  -f2 > boot.img-os;
    grep "Type:" header | cut -c15- | cut -d\  -f3 | cut -d- -f1 > boot.img-type;
    grep "Type:" header | cut -d\( -f2 | cut -d\) -f1 | cut -d\  -f1 | cut -d- -f1 > boot.img-comp;
    grep "Address:" header | cut -c15- > boot.img-addr;
    grep "Point:" header | cut -c15- > boot.img-ep;
    $bin/dumpimage -p 0 -o kernel.gz boot-trimmed.img;
    [ $? != 0 ] && dumpfail=1;
    case $(cat boot.img-type) in
      Multi) $bin/dumpimage -p 1 -o ramdisk.cpio.gz boot-trimmed.img;;
      RAMDisk) mv -f kernel.gz ramdisk.cpio.gz;;
    esac;
  elif [ -f "$bin/rkcrc" ]; then
    dd bs=4096 skip=8 iflag=skip_bytes conv=notrunc if=$bootimg of=ramdisk.cpio.gz;
  else
    $bin/magiskboot unpack -h $bootimg;
    case $? in
      1) dumpfail=1;;
      2) touch chromeos;;
    esac;
  fi;

  if [ $? != 0 -o "$dumpfail" ]; then
    abort "Dumping/splitting image failed. Aborting...";
  fi;
  cd $home;
}

# unpack_ramdisk (extract ramdisk only)
unpack_ramdisk() {
  local comp;

  cd $split_img;
  if [ -f ramdisk.cpio.gz ]; then
    if [ -f "$bin/mkmtkhdr" ]; then
      mv -f ramdisk.cpio.gz ramdisk.cpio.gz-mtk;
      dd bs=512 skip=1 conv=notrunc if=ramdisk.cpio.gz-mtk of=ramdisk.cpio.gz;
    fi;
    mv -f ramdisk.cpio.gz ramdisk.cpio;
  fi;

  if [ -f ramdisk.cpio ]; then
    comp=$($bin/magiskboot decompress ramdisk.cpio 2>&1 | grep -v 'raw' | sed -n 's;.*\[\(.*\)\];\1;p');
  else
    abort "No ramdisk found to unpack. Aborting...";
  fi;
  if [ "$comp" ]; then
    mv -f ramdisk.cpio ramdisk.cpio.$comp;
    $bin/magiskboot decompress ramdisk.cpio.$comp ramdisk.cpio;
    if [ $? != 0 ] && $comp --help 2>/dev/null; then
      echo "Attempting ramdisk unpack with busybox $comp..." >&2;
      $comp -dc ramdisk.cpio.$comp > ramdisk.cpio;
    fi;
  fi;

  [ -d $ramdisk ] && mv -f $ramdisk $home/rdtmp;
  mkdir -p $ramdisk;
  chmod 755 $ramdisk;

  cd $ramdisk;
  EXTRACT_UNSAFE_SYMLINKS=1 cpio -d -F $split_img/ramdisk.cpio -i;
  if [ $? != 0 -o ! "$(ls)" ]; then
    abort "Unpacking ramdisk failed. Aborting...";
  fi;
  if [ -d "$home/rdtmp" ]; then
    cp -af $home/rdtmp/* .;
  fi;
}
### dump_boot (dump and split image, then extract ramdisk)
dump_boot() {
  split_boot;
  unpack_ramdisk;
}
###

### write_boot functions:
# repack_ramdisk (repack ramdisk only)
repack_ramdisk() {
  local comp packfail mtktype;

  cd $home;
  case $ramdisk_compression in
    auto|"") comp=$(ls $split_img/ramdisk.cpio.* 2>/dev/null | grep -v 'mtk' | rev | cut -d. -f1 | rev);;
    none|cpio) comp="";;
    gz) comp=gzip;;
    lzo) comp=lzop;;
    bz2) comp=bzip2;;
    lz4-l) comp=lz4_legacy;;
    *) comp=$ramdisk_compression;;
  esac;

  if [ -f "$bin/mkbootfs" ]; then
    $bin/mkbootfs $ramdisk > ramdisk-new.cpio;
  else
    cd $ramdisk;
    find . | cpio -H newc -o > $home/ramdisk-new.cpio;
  fi;
  [ $? != 0 ] && packfail=1;

  cd $home;
  if [ ! "$no_magisk_check" ]; then
    $bin/magiskboot cpio ramdisk-new.cpio test;
    magisk_patched=$?;
  fi;
  [ $((magisk_patched & 3)) -eq 1 ] && $bin/magiskboot cpio ramdisk-new.cpio "extract .backup/.magisk $split_img/.magisk";
  if [ "$comp" ]; then
    $bin/magiskboot compress=$comp ramdisk-new.cpio;
    if [ $? != 0 ] && $comp --help 2>/dev/null; then
      echo "Attempting ramdisk repack with busybox $comp..." >&2;
      $comp -9c ramdisk-new.cpio > ramdisk-new.cpio.$comp;
      [ $? != 0 ] && packfail=1;
      rm -f ramdisk-new.cpio;
    fi;
  fi;
  if [ "$packfail" ]; then
    abort "Repacking ramdisk failed. Aborting...";
  fi;

  if [ -f "$bin/mkmtkhdr" -a -f "$split_img/boot.img-base" ]; then
    mtktype=$(od -ta -An -N8 -j8 $split_img/ramdisk.cpio.gz-mtk | sed -e 's/ nul//g' -e 's/   //g' | tr '[:upper:]' '[:lower:]');
    case $mtktype in
      rootfs|recovery) $bin/mkmtkhdr --$mtktype ramdisk-new.cpio*;;
    esac;
  fi;
}

# flash_boot (build, sign and write image only)
flash_boot() {
  local varlist i kernel ramdisk fdt cmdline comp part0 part1 nocompflag signfail pk8 cert avbtype;

  cd $split_img;
  if [ -f "$bin/mkimage" ]; then
    varlist="name arch os type comp addr ep";
  elif [ -f "$bin/mkbootimg" -a -f "$bin/unpackelf" -a -f boot.img-base ]; then
    mv -f cmdline.txt boot.img-cmdline 2>/dev/null;
    varlist="cmdline base pagesize kernel_offset ramdisk_offset tags_offset";
  fi;
  for i in $varlist; do
    if [ -f boot.img-$i ]; then
      eval local $i=\"$(cat boot.img-$i)\";
    fi;
  done;

  cd $home;
  for i in zImage zImage-dtb Image Image-dtb Image.gz Image.gz-dtb Image.bz2 Image.bz2-dtb Image.lzo Image.lzo-dtb Image.lzma Image.lzma-dtb Image.xz Image.xz-dtb Image.lz4 Image.lz4-dtb Image.fit; do
    if [ -f $i ]; then
      kernel=$home/$i;
      break;
    fi;
  done;
  if [ "$kernel" ]; then
    if [ -f "$bin/mkmtkhdr" -a -f "$split_img/boot.img-base" ]; then
      $bin/mkmtkhdr --kernel $kernel;
      kernel=$kernel-mtk;
    fi;
  elif [ "$(ls $split_img/kernel* 2>/dev/null)" ]; then
    kernel=$(ls $split_img/kernel* | grep -v 'kernel_dtb' | tail -n1);
  fi;
  if [ "$(ls ramdisk-new.cpio* 2>/dev/null)" ]; then
    ramdisk=$home/$(ls ramdisk-new.cpio* | tail -n1);
  elif [ -f "$bin/mkmtkhdr" -a -f "$split_img/boot.img-base" ]; then
    ramdisk=$split_img/ramdisk.cpio.gz-mtk;
  else
    ramdisk=$(ls $split_img/ramdisk.cpio* 2>/dev/null | tail -n1);
  fi;
  for fdt in dt recovery_dtbo dtb; do
    for i in $home/$fdt $home/$fdt.img $split_img/$fdt; do
      if [ -f $i ]; then
        eval local $fdt=$i;
        break;
      fi;
    done;
  done;

  cd $split_img;
  if [ -f "$bin/mkimage" ]; then
    [ "$comp" == "uncompressed" ] && comp=none;
    part0=$kernel;
    case $type in
      Multi) part1=":$ramdisk";;
      RAMDisk) part0=$ramdisk;;
    esac;
    $bin/mkimage -A $arch -O $os -T $type -C $comp -a $addr -e $ep -n "$name" -d $part0$part1 $home/boot-new.img;
  elif [ -f "$bin/elftool" ]; then
    [ "$dt" ] && dt="$dt,rpm";
    [ -f cmdline.txt ] && cmdline="cmdline.txt@cmdline";
    $bin/elftool pack -o $home/boot-new.img header=elftool_out/header $kernel $ramdisk,ramdisk $dt $cmdline;
  elif [ -f "$bin/mboot" ]; then
    cp -f $kernel kernel;
    cp -f $ramdisk ramdisk.cpio.gz;
    $bin/mboot -d $split_img -f $home/boot-new.img;
  elif [ -f "$bin/rkcrc" ]; then
    $bin/rkcrc -k $ramdisk $home/boot-new.img;
  elif [ -f "$bin/mkbootimg" -a -f "$bin/unpackelf" -a -f boot.img-base ]; then
    [ "$dt" ] && dt="--dt $dt";
    $bin/mkbootimg --kernel $kernel --ramdisk $ramdisk --cmdline "$cmdline" --base $base --pagesize $pagesize --kernel_offset $kernel_offset --ramdisk_offset $ramdisk_offset --tags_offset "$tags_offset" $dt --output $home/boot-new.img;
  else
    [ "$kernel" ] && cp -f $kernel kernel;
    [ "$ramdisk" ] && cp -f $ramdisk ramdisk.cpio;
    [ "$dt" -a -f extra ] && cp -f $dt extra;
    for i in dtb recovery_dtbo; do
      [ "$(eval echo \$$i)" -a -f $i ] && cp -f $(eval echo \$$i) $i;
    done;
    case $kernel in
      *Image*)
        if [ ! "$magisk_patched" -a ! "$no_magisk_check" ]; then
          $bin/magiskboot cpio ramdisk.cpio test;
          magisk_patched=$?;
        fi;
        if [ $((magisk_patched & 3)) -eq 1 ]; then
          ui_print " " "Magisk detected! Patching kernel so reflashing Magisk is not necessary...";
          comp=$($bin/magiskboot decompress kernel 2>&1 | grep -vE 'raw|zimage' | sed -n 's;.*\[\(.*\)\];\1;p');
          ($bin/magiskboot split $kernel || $bin/magiskboot decompress $kernel kernel) 2>/dev/null;
          if [ $? != 0 -a "$comp" ] && $comp --help 2>/dev/null; then
            echo "Attempting kernel unpack with busybox $comp..." >&2;
            $comp -dc $kernel > kernel;
          fi;
          # legacy SAR kernel string skip_initramfs -> want_initramfs
          $bin/magiskboot hexpatch kernel 736B69705F696E697472616D6673 77616E745F696E697472616D6673;
          if [ "$(file_getprop $home/anykernel.sh do.modules)" == 1 ] && [ "$(file_getprop $home/anykernel.sh do.systemless)" == 1 ]; then
            strings kernel 2>/dev/null | grep -E -m1 'Linux version.*#' > $home/vertmp;
          fi;
          if [ "$comp" ]; then
            $bin/magiskboot compress=$comp kernel kernel.$comp;
            if [ $? != 0 ] && $comp --help 2>/dev/null; then
              echo "Attempting kernel repack with busybox $comp..." >&2;
              $comp -9c kernel > kernel.$comp;
            fi;
            mv -f kernel.$comp kernel;
          fi;
          [ ! -f .magisk ] && $bin/magiskboot cpio ramdisk.cpio "extract .backup/.magisk .magisk";
          export $(cat .magisk);
          for fdt in dtb extra kernel_dtb recovery_dtbo; do
            [ -f $fdt ] && $bin/magiskboot dtb $fdt patch; # remove dtb verity/avb
          done;
        elif [ -d /data/data/me.weishu.kernelsu ] && [ "$(file_getprop $home/anykernel.sh do.modules)" == 1 ] && [ "$(file_getprop $home/anykernel.sh do.systemless)" == 1 ]; then
          ui_print " " "KernelSU detected! Setting up for kernel helper module...";
          comp=$($bin/magiskboot decompress kernel 2>&1 | grep -vE 'raw|zimage' | sed -n 's;.*\[\(.*\)\];\1;p');
          ($bin/magiskboot split $kernel || $bin/magiskboot decompress $kernel kernel) 2>/dev/null;
          if [ $? != 0 -a "$comp" ] && $comp --help 2>/dev/null; then
            echo "Attempting kernel unpack with busybox $comp..." >&2;
            $comp -dc $kernel > kernel;
          fi;
          if strings kernel 2>/dev/null | grep -q -E '^/data/adb/ksud$'; then
            touch $home/kernelsu_patched;
            strings kernel 2>/dev/null | grep -E -m1 'Linux version.*#' > $home/vertmp;
          else
            ui_print " " "Warning: No KernelSU support detected in kernel!";
          fi;
          if [ "$comp" ]; then
            $bin/magiskboot compress=$comp kernel kernel.$comp;
            if [ $? != 0 ] && $comp --help 2>/dev/null; then
              echo "Attempting kernel repack with busybox $comp..." >&2;
              $comp -9c kernel > kernel.$comp;
            fi;
            mv -f kernel.$comp kernel;
          fi;
        else
          case $kernel in
            *-dtb) rm -f kernel_dtb;;
          esac;
        fi;
        unset magisk_patched KEEPVERITY KEEPFORCEENCRYPT RECOVERYMODE PREINITDEVICE SHA1 RANDOMSEED; # leave PATCHVBMETAFLAG set for repack
      ;;
    esac;
    case $ramdisk_compression in
      none|cpio) nocompflag="-n";;
    esac;
    case $patch_vbmeta_flag in
      auto|"") [ "$PATCHVBMETAFLAG" ] || export PATCHVBMETAFLAG=false;;
      1) export PATCHVBMETAFLAG=true;;
      *) export PATCHVBMETAFLAG=false;;
    esac;
    $bin/magiskboot repack $nocompflag $bootimg $home/boot-new.img;
    unset PATCHVBMETAFLAG;
  fi;
  if [ $? != 0 ]; then
    abort "Repacking image failed. Aborting...";
  fi;
  [ -f .magisk ] && touch $home/magisk_patched;

  cd $home;
  if [ -f "$bin/futility" -a -d "$bin/chromeos" ]; then
    if [ -f "$split_img/chromeos" ]; then
      echo "Signing with CHROMEOS..." >&2;
      $bin/futility vbutil_kernel --pack boot-new-signed.img --keyblock $bin/chromeos/kernel.keyblock --signprivate $bin/chromeos/kernel_data_key.vbprivk --version 1 --vmlinuz boot-new.img --bootloader $bin/chromeos/empty --config $bin/chromeos/empty --arch arm --flags 0x1;
    fi;
    [ $? != 0 ] && signfail=1;
  fi;
  if [ -f "$bin/boot_signer-dexed.jar" -a -d "$bin/avb" ]; then
    pk8=$(ls $bin/avb/*.pk8);
    cert=$(ls $bin/avb/*.x509.*);
    case $block in
      *recovery*|*SOS*) avbtype=recovery;;
      *) avbtype=boot;;
    esac;
    if [ -f /system/bin/dalvikvm ] && [ "$(/system/bin/dalvikvm -Xnoimage-dex2oat -cp $bin/boot_signer-dexed.jar com.android.verity.BootSignature -verify boot.img 2>&1 | grep VALID)" ]; then
      echo "Signing with AVBv1..." >&2;
      /system/bin/dalvikvm -Xnoimage-dex2oat -cp $bin/boot_signer-dexed.jar com.android.verity.BootSignature /$avbtype boot-new.img $pk8 $cert boot-new-signed.img;
    fi;
  fi;
  if [ $? != 0 -o "$signfail" ]; then
    abort "Signing image failed. Aborting...";
  fi;
  mv -f boot-new-signed.img boot-new.img 2>/dev/null;

  if [ ! -f boot-new.img ]; then
    abort "No repacked image found to flash. Aborting...";
  elif [ "$(wc -c < boot-new.img)" -gt "$(wc -c < boot.img)" ]; then
    abort "New image larger than target partition. Aborting...";
  fi;
  blockdev --setrw $block 2>/dev/null;
  if [ -f "$bin/flash_erase" -a -f "$bin/nandwrite" ]; then
    $bin/flash_erase $block 0 0;
    $bin/nandwrite -p $block boot-new.img;
  elif [ "$customdd" ]; then
    dd if=/dev/zero of=$block $customdd 2>/dev/null;
    dd if=boot-new.img of=$block $customdd;
  else
    cat boot-new.img /dev/zero > $block 2>/dev/null || true;
  fi;
  if [ $? != 0 ]; then
    abort "Flashing image failed. Aborting...";
  fi;
}

# flash_generic <name>
flash_generic() {
  local avb avbblock avbpath file flags img imgblock imgsz isro isunmounted path;

  cd $home;
  for file in $1 $1.img; do
    if [ -f $file ]; then
      img=$file;
      break;
    fi;
  done;

  if [ "$img" -a ! -f ${1}_flashed ]; then
    for path in /dev/block/mapper /dev/block/by-name /dev/block/bootdevice/by-name; do
      for file in $1 $1$slot; do
        if [ -e $path/$file ]; then
          imgblock=$path/$file;
          break 2;
        fi;
      done;
    done;
    if [ ! "$imgblock" ]; then
      abort "$1 partition could not be found. Aborting...";
    fi;
    if [ ! "$no_block_display" ]; then
      ui_print " " "$imgblock";
    fi;
    if [ "$path" == "/dev/block/mapper" ]; then
      avb=$($bin/httools_static avb $1);
      [ $? == 0 ] || abort "Failed to parse fstab entry for $1. Aborting...";
      if [ "$avb" ]; then
        flags=$($bin/httools_static disable-flags);
        [ $? == 0 ] || abort "Failed to parse top-level vbmeta. Aborting...";
        if [ "$flags" == "enabled" ]; then
          ui_print " " "dm-verity detected! Patching $avb...";
          for avbpath in /dev/block/mapper /dev/block/by-name /dev/block/bootdevice/by-name; do
            for file in $avb $avb$slot; do
              if [ -e $avbpath/$file ]; then
                avbblock=$avbpath/$file;
                break 2;
              fi;
            done;
          done;
          cd $bin;
          $bin/httools_static patch $1 $home/$img $avbblock || abort "Failed to patch $1 on $avb. Aborting...";
          cd $home;
        fi
      fi
      imgsz=$(wc -c < $img);
      if [ "$imgsz" != "$(wc -c < $imgblock)" ]; then
        if [ -d /postinstall/tmp -a "$slot_select" == "inactive" ]; then
          echo "Resizing $1$slot snapshot..." >&2;
          $bin/snapshotupdater_static update $1 $imgsz || abort "Resizing $1$slot snapshot failed. Aborting...";
        else
          echo "Removing any existing $1_ak3..." >&2;
          $bin/lptools_static remove $1_ak3;
          echo "Clearing any merged cow partitions..." >&2;
          $bin/lptools_static clear-cow;
          echo "Attempting to create $1_ak3..." >&2;
          if $bin/lptools_static create $1_ak3 $imgsz; then
            echo "Replacing $1$slot with $1_ak3..." >&2;
            $bin/lptools_static unmap $1_ak3 || abort "Unmapping $1_ak3 failed. Aborting...";
            $bin/lptools_static map $1_ak3 || abort "Mapping $1_ak3 failed. Aborting...";
            $bin/lptools_static replace $1_ak3 $1$slot || abort "Replacing $1$slot failed. Aborting...";
            imgblock=/dev/block/mapper/$1_ak3;
            ui_print " " "Warning: $1$slot replaced in super. Reboot before further logical partition operations.";
          else
            echo "Creating $1_ak3 failed. Attempting to resize $1$slot..." >&2;
            $bin/httools_static umount $1 || abort "Unmounting $1 failed. Aborting...";
            if [ -e $path/$1-verity ]; then
              $bin/lptools_static unmap $1-verity || abort "Unmapping $1-verity failed. Aborting...";
            fi
            $bin/lptools_static unmap $1$slot || abort "Unmapping $1$slot failed. Aborting...";
            $bin/lptools_static resize $1$slot $imgsz || abort "Resizing $1$slot failed. Aborting...";
            $bin/lptools_static map $1$slot || abort "Mapping $1$slot failed. Aborting...";
            isunmounted=1;
          fi
        fi
      fi
    elif [ "$(wc -c < $img)" -gt "$(wc -c < $imgblock)" ]; then
      abort "New $1 image larger than $1 partition. Aborting...";
    fi;
    isro=$(blockdev --getro $imgblock 2>/dev/null);
    blockdev --setrw $imgblock 2>/dev/null;
    if [ -f "$bin/flash_erase" -a -f "$bin/nandwrite" ]; then
      $bin/flash_erase $imgblock 0 0;
      $bin/nandwrite -p $imgblock $img;
    elif [ "$customdd" ]; then
      dd if=/dev/zero of=$imgblock 2>/dev/null;
      dd if=$img of=$imgblock;
    else
      cat $img /dev/zero > $imgblock 2>/dev/null || true;
    fi;
    if [ $? != 0 ]; then
      abort "Flashing $1 failed. Aborting...";
    fi;
    if [ "$isro" != 0 ]; then
      blockdev --setro $imgblock 2>/dev/null;
    fi;
    if [ "$isunmounted" -a "$path" == "/dev/block/mapper" ]; then
      $bin/httools_static mount $1 || abort "Mounting $1 failed. Aborting...";
    fi
    touch ${1}_flashed;
  fi;
}

# flash_dtbo (backwards compatibility for flash_generic)
flash_dtbo() { flash_generic dtbo; }

### write_boot (repack ramdisk then build, sign and write image, vendor_dlkm and dtbo)
write_boot() {
  repack_ramdisk;
  flash_boot;
  flash_generic vendor_boot; # temporary until hdr v4 can be unpacked/repacked fully by magiskboot
  flash_generic vendor_kernel_boot; # temporary until hdr v4 can be unpacked/repacked fully by magiskboot
  flash_generic vendor_dlkm;
  flash_generic dtbo;
}
###

### file editing functions:
# backup_file <file>
backup_file() { [ ! -f $1~ ] && cp -fp $1 $1~; }

# restore_file <file>
restore_file() { [ -f $1~ ] && cp -fp $1~ $1; rm -f $1~; }

# replace_string <file> <if search string> <original string> <replacement string> <scope>
replace_string() {
  [ "$5" == "global" ] && local scope=g;
  if ! grep -q "$2" $1; then
    sed -i "s;${3};${4};${scope}" $1;
  fi;
}

# replace_section <file> <begin search string> <end search string> <replacement string>
replace_section() {
  local begin endstr last end;
  begin=$(grep -n -m1 "$2" $1 | cut -d: -f1);
  if [ "$begin" ]; then
    if [ "$3" == " " -o ! "$3" ]; then
      endstr='^[[:space:]]*$';
      last=$(wc -l $1 | cut -d\  -f1);
    else
      endstr="$3";
    fi;
    for end in $(grep -n "$endstr" $1 | cut -d: -f1) $last; do
      if [ "$end" ] && [ "$begin" -lt "$end" ]; then
        sed -i "${begin},${end}d" $1;
        [ "$end" == "$last" ] && echo >> $1;
        sed -i "${begin}s;^;${4}\n;" $1;
        break;
      fi;
    done;
  fi;
}

# remove_section <file> <begin search string> <end search string>
remove_section() {
  local begin endstr last end;
  begin=$(grep -n -m1 "$2" $1 | cut -d: -f1);
  if [ "$begin" ]; then
    if [ "$3" == " " -o ! "$3" ]; then
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
  if ! grep -q "$2" $1; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n -m1 "$4" $1 | cut -d: -f1` + offset));
    if [ -f $1 -a "$line" ] && [ "$(wc -l $1 | cut -d\  -f1)" -lt "$line" ]; then
      echo "$5" >> $1;
    else
      sed -i "${line}s;^;${5}\n;" $1;
    fi;
  fi;
}

# replace_line <file> <line replace string> <replacement line> <scope>
replace_line() {
  local lines line;
  if grep -q "$2" $1; then
    lines=$(grep -n "$2" $1 | cut -d: -f1 | sort -nr);
    [ "$4" == "global" ] || lines=$(echo "$lines" | tail -n1);
    for line in $lines; do
      sed -i "${line}s;.*;${3};" $1;
    done;
  fi;
}

# remove_line <file> <line match string> <scope>
remove_line() {
  local lines line;
  if grep -q "$2" $1; then
    lines=$(grep -n "$2" $1 | cut -d: -f1 | sort -nr);
    [ "$3" == "global" ] || lines=$(echo "$lines" | tail -n1);
    for line in $lines; do
      sed -i "${line}d" $1;
    done;
  fi;
}

# prepend_file <file> <if search string> <patch file>
prepend_file() {
  if ! grep -q "$2" $1; then
    echo "$(cat $patch/$3 $1)" > $1;
  fi;
}

# insert_file <file> <if search string> <before|after> <line match string> <patch file>
insert_file() {
  local offset line;
  if ! grep -q "$2" $1; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n -m1 "$4" $1 | cut -d: -f1` + offset));
    sed -i "${line}s;^;\n;" $1;
    sed -i "$((line - 1))r $patch/$5" $1;
  fi;
}

# append_file <file> <if search string> <patch file>
append_file() {
  if ! grep -q "$2" $1; then
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

# patch_fstab <fstab file> <mount match name> <fs match type> block|mount|fstype|options|flags <original string> <replacement string>
patch_fstab() {
  local entry part newpart newentry;
  entry=$(grep "$2[[:space:]]" $1 | grep "$3");
  if [ ! "$(echo "$entry" | grep "$6")" -o "$6" == " " -o ! "$6" ]; then
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
  if [ -f "$split_img/cmdline.txt" ]; then
    cmdfile=$split_img/cmdline.txt;
  else
    cmdfile=$home/cmdtmp;
    grep "^cmdline=" $split_img/header | cut -d= -f2- > $cmdfile;
  fi;
  if ! grep -q "$1" $cmdfile; then
    cmdtmp=$(cat $cmdfile);
    echo "$cmdtmp $2" > $cmdfile;
    sed -i -e 's;^[ \t]*;;' -e 's;  *; ;g' -e 's;[ \t]*$;;' $cmdfile;
  else
    match=$(grep -o "$1.*$" $cmdfile | cut -d\  -f1);
    sed -i -e "s;${match};${2};" -e 's;^[ \t]*;;' -e 's;  *; ;g' -e 's;[ \t]*$;;' $cmdfile;
  fi;
  if [ -f "$home/cmdtmp" ]; then
    sed -i "s|^cmdline=.*|cmdline=$(cat $cmdfile)|" $split_img/header;
    rm -f $cmdfile;
  fi;
}

# patch_prop <prop file> <prop name> <new prop value>
patch_prop() {
  if ! grep -q "^$2=" $1; then
    echo -ne "\n$2=$3\n" >> $1;
  else
    local line=$(grep -n -m1 "^$2=" $1 | cut -d: -f1);
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
  line=$(grep -n -m1 "$dev" $file | cut -d: -f1);
  if [ "$line" ]; then
    sed -i "${line}s;.*;${newentry};" $file;
  else
    echo -ne "\n$newentry\n" >> $file;
  fi;
}
###

### configuration/setup functions:
# reset_ak [keep]
reset_ak() {
  local current i;

  current=$(dirname $home/*-files/current);
  if [ -d "$current" ]; then
    for i in $bootimg $home/boot-new.img; do
      [ -e $i ] && cp -af $i $current;
    done;
    for i in $current/*; do
      [ -f $i ] && rm -f $home/$(basename $i);
    done;
  fi;
  [ -d $split_img ] && rm -rf $ramdisk;
  rm -rf $bootimg $split_img $home/*-new* $home/*-files/current;

  if [ "$1" == "keep" ]; then
    [ -d $home/rdtmp ] && mv -f $home/rdtmp $ramdisk;
  else
    rm -rf $patch $home/rdtmp;
  fi;
  if [ ! "$no_block_display" ]; then
    ui_print " ";
  fi;
  setup_ak;
}

# setup_ak
setup_ak() {
  local blockfiles plistboot plistinit plistreco parttype name part mtdmount mtdpart mtdname target;

  # slot detection enabled by is_slot_device=1 or auto (from anykernel.sh)
  case $is_slot_device in
    1|auto)
      slot=$(getprop ro.boot.slot_suffix 2>/dev/null);
      [ "$slot" ] || slot=$(grep -o 'androidboot.slot_suffix=.*$' /proc/cmdline | cut -d\  -f1 | cut -d= -f2);
      if [ ! "$slot" ]; then
        slot=$(getprop ro.boot.slot 2>/dev/null);
        [ "$slot" ] || slot=$(grep -o 'androidboot.slot=.*$' /proc/cmdline | cut -d\  -f1 | cut -d= -f2);
        [ "$slot" ] && slot=_$slot;
      fi;
      [ "$slot" == "normal" ] && unset slot;
      if [ "$slot" ]; then
        if [ -d /postinstall/tmp -a ! "$slot_select" ]; then
          slot_select=inactive;
        fi;
        case $slot_select in
          inactive)
            case $slot in
              _a) slot=_b;;
              _b) slot=_a;;
            esac;
          ;;
        esac;
      fi;
      if [ ! "$slot" -a "$is_slot_device" == 1 ]; then
        abort "Unable to determine active slot. Aborting...";
      fi;
    ;;
  esac;

  # clean up any template placeholder files
  cd $home;
  rm -f modules/system/lib/modules/placeholder patch/placeholder ramdisk/placeholder;
  rmdir -p modules patch ramdisk 2>/dev/null;

  # automate simple multi-partition setup for hdr_v4 boot + init_boot + vendor_kernel_boot (for dtb only until magiskboot supports hdr v4 vendor_ramdisk unpack/repack)
  if [ -e "/dev/block/bootdevice/by-name/init_boot$slot" -a ! -f init_v4_setup ] && [ -f dtb -o -d vendor_ramdisk -o -d vendor_patch ]; then
    echo "Setting up for simple automatic init_boot flashing..." >&2;
    (mkdir boot-files;
    mv -f Image* boot-files;
    mkdir init_boot-files;
    mv -f ramdisk patch init_boot-files;
    mkdir vendor_kernel_boot-files;
    mv -f dtb vendor_kernel_boot-files;
    mv -f vendor_ramdisk vendor_kernel_boot-files/ramdisk;
    mv -f vendor_patch vendor_kernel_boot-files/patch) 2>/dev/null;
    touch init_v4_setup;
  # automate simple multi-partition setup for hdr_v3+ boot + vendor_boot with dtb/dlkm (for v3 only until magiskboot supports hdr v4 vendor_ramdisk unpack/repack)
  elif [ -e "/dev/block/bootdevice/by-name/vendor_boot$slot" -a ! -f vendor_v3_setup ] && [ -f dtb -o -d vendor_ramdisk -o -d vendor_patch ]; then
    echo "Setting up for simple automatic vendor_boot flashing..." >&2;
    (mkdir boot-files;
    mv -f Image* ramdisk patch boot-files;
    mkdir vendor_boot-files;
    mv -f dtb vendor_boot-files;
    mv -f vendor_ramdisk vendor_boot-files/ramdisk;
    mv -f vendor_patch vendor_boot-files/patch) 2>/dev/null;
    touch vendor_v3_setup;
  fi;

  # target block partition detection enabled by block=<partition filename> or auto (from anykernel.sh)
  case $block in
    /dev/*)
      if [ "$slot" ] && [ -e "$block$slot" ]; then
        target=$block$slot;
      elif [ -e "$block" ]; then
        target=$block;
      fi;
    ;;
    *)
      # maintain brief lists of historic matching partition type names for boot, recovery and init_boot/ramdisk
      plistboot="boot BOOT LNX android_boot bootimg KERN-A kernel KERNEL";
      plistreco="recovery RECOVERY SOS android_recovery recovery_ramdisk";
      plistinit="init_boot ramdisk";
      case $block in
        auto) parttype="$plistinit $plistboot";;
        boot|kernel) parttype=$plistboot;;
        recovery|recovery_ramdisk) parttype=$plistreco;;
        init_boot|ramdisk) parttype=$plistinit;;
        *) parttype=$block;;
      esac;
      for name in $parttype; do
        for part in $name$slot $name; do
          if [ "$(grep -w "$part" /proc/mtd 2> /dev/null)" ]; then
            mtdmount=$(grep -w "$part" /proc/mtd);
            mtdpart=$(echo $mtdmount | cut -d\" -f2);
            if [ "$mtdpart" == "$part" ]; then
              mtdname=$(echo $mtdmount | cut -d: -f1);
            else
              abort "Unable to determine mtd $block partition. Aborting...";
            fi;
            [ -e /dev/mtd/$mtdname ] && target=/dev/mtd/$mtdname;
          elif [ -e /dev/block/by-name/$part ]; then
            target=/dev/block/by-name/$part;
          elif [ -e /dev/block/bootdevice/by-name/$part ]; then
            target=/dev/block/bootdevice/by-name/$part;
          elif [ -e /dev/block/platform/*/by-name/$part ]; then
            target=/dev/block/platform/*/by-name/$part;
          elif [ -e /dev/block/platform/*/*/by-name/$part ]; then
            target=/dev/block/platform/*/*/by-name/$part;
          elif [ -e /dev/$part ]; then
            target=/dev/$part;
          fi;
          [ "$target" ] && break 2;
        done;
      done;
    ;;
  esac;
  if [ "$target" ]; then
    block=$(ls $target 2>/dev/null);
  else
    abort "Unable to determine $block partition. Aborting...";
  fi;
  if [ ! "$no_block_display" ]; then
    ui_print "$block";
  fi;
  
  # allow multi-partition ramdisk modifying configurations (using reset_ak)
  name=$(basename $block | sed -e 's/_a$//' -e 's/_b$//');
  if [ "$block" ] && [ ! -d "$ramdisk" -a ! -d "$patch" ]; then
    blockfiles=$home/$name-files;
    if [ "$(ls $blockfiles 2>/dev/null)" ]; then
      cp -af $blockfiles/* $home;
    else
      mkdir $blockfiles;
    fi;
    touch $blockfiles/current;
  fi;

  # run attributes function for current block if it exists
  type attributes >/dev/null 2>&1 && attributes; # backwards compatibility
  type ${name}_attributes >/dev/null 2>&1 && ${name}_attributes;
}
###

### end methods

setup_ak;
