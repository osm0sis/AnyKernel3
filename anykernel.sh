# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=aRiseKernel By Prashant
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=lavender
supported.versions=
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;
keep_vbmeta_flag=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 $ramdisk/*;
chown -R root:root $ramdisk/*;

## AnyKernel boot install
dump_boot;

## begin ramdisk changes
# Set Android version for kernel
ver="$(file_getprop /system/build.prop ro.build.version.release)"
if [ ! -z "$ver" ]; then
    patch_cmdline "androidboot.version" "androidboot.version=$ver"
else
    patch_cmdline "androidboot.version" ""
fi

write_boot;
## end install
