# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=UghTea by @D4rkKnight21
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=platina
device.name2=Mi8Lite
device.name3=Mi8lite
device.name4=8lite
device.name5=Platina
supported.versions=
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/bootdevice/by-name/boot
is_slot_device=0;
ramdisk_compression=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;


## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 $ramdisk/*;
chown -R root:root $ramdisk/*;


## AnyKernel install
dump_boot;

# Add skip_override parameter to cmdline so user doesn't have to reflash Magisk
if [ -d $ramdisk/.backup ]; then
  ui_print " "; ui_print "Magisk detected! Patching cmdline so reflashing Magisk is not necessary...";
  patch_cmdline "skip_override" "skip_override";
else
  patch_cmdline "skip_override" "";
fi;

write_boot;
## end install

