# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
do.volkeyinstall=1
do.devicecheck=1
do.modules=0
do.cleanup=1
do.cleanuponabort=0
<<<<<<< HEAD
device.name1=joan
supported.versions=8.0.0, 9
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;


## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
set_perm_recursive 0 0 755 644 $ramdisk/*;
set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;


## AnyKernel install
dump_boot;

# begin ramdisk changes

# init.rc
android_ver=$(file_getprop /system/build.prop ro.build.version.release);
selinux=<selinux>

if [ $android_ver == 8.0.0 ]; then
  ui_print " Backing up init.joan.rc";
  backup_file init.joan.rc;
  ui_print " Adding init.rc import for Jolla Kernel in init.joan.rc";
#  grep "init.jolla-kernel.rc" init.joan.rc && { ui_print " Import already added" || sed -i "/import \/init.msm8998_core.rc/a import /init.jolla-kernel.rc" init.joan.rc; }
  if grep "init.jolla-kernel.rc" init.joan.rc; then
    ui_print "Import Already Added"
  else
    sed -i "/import \/init.msm8998_core.rc/a import /init.jolla-kernel.rc" init.joan.rc
  fi
else
  ui_print " Backing up init.rc";
  backup_file init.rc;
  backup_file init.joan.power.rc;
  ui_print " Adding init.rc import for Jolla Kernel in init.rc";
#  grep "init.jolla-kernel.rc" init.rc && { ui_print " Import already added" || sed -i "/import \/init.usb.configfs.rc/a import /init.jolla-kernel.rc" init.rc; }
  if grep "init.jolla-kernel.rc" init.rc; then
    ui_print "Import Already Added"
  else
    sed -i "/import \/init.usb.configfs.rc/a import /init.jolla-kernel.rc" init.rc
  fi
  ui_print " Disabling Triton and Cancun"
  sed -i '/triton/s/^/#/g' init.joan.power.rc;
  sed -i '/class/s/^/#/1' init.joan.power.rc;
  sed -i '/user/s/^/#/1' init.joan.power.rc;
  sed -i '/group/s/^/#/1' init.joan.power.rc;
  sed -i '/disabled/s/^/#/1' init.joan.power.rc;
  sed -i '/on/s/^/#/1/'  init.joan.power.rc;
fi;
# end ramdisk changes

if [ "$selinux" == yes ]; then
  patch_cmdline "androidboot.selinux=permissive" "androidboot.selinux=permissive"
  patch_cmdline "androidboot.selinux=enforcing" ""
fi
if [ "$selinux" == no ]; then
  patch_cmdline "androidboot.selinux=permissive" ""
fi

write_boot;
## end install
