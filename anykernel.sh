# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=
do.devicecheck=0
do.modules=0
do.cleanup=1
do.cleanuponabort=0
device.name1=
'; } # end properties

# shell variables
block=/dev/block/platform/13540000.dwmmc0/by-name/BOOT;
is_slot_device=0;
ramdisk_compression=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. /tmp/anykernel/tools/ak2-core.sh;


## AnyKernel install
dump_boot;


# Enable Spectrum Support
ui_print " ";
ui_print "Enabling spectrum support...";
replace_file sbin/spa 755 spectrum/spa;
replace_file init.spectrum.rc 644 spectrum/init.spectrum.rc;
insert_line init.samsungexynos7870.rc "import init.spectrum.rc" after "import init.fac.rc" "import init.spectrum.rc";
ui_print " ";
ui_print "Installing spectrum profiles...";
rm -rf /data/media/0/Spectrum;
cp -r /tmp/anykernel/Spectrum /data/media/0/Spectrum;
chmod 777 /data/media/0/Spectrum/profiles;

write_boot;

## end install
