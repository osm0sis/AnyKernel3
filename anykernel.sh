# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# EDIFY properties
kernel.string=DirtyV by bsmitty83 @ xda-developers
do.devicecheck=1
do.initd=1
do.modules=0
do.cleanup=1
do.cleanuponabort=0
device.name1=maguro
device.name2=toro
device.name3=toroplus
device.name4=
device.name5=

# shell variables
block=/dev/block/platform/omap/omap_hsmmc.0/by-name/boot;
is_slot_device=0;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. /tmp/anykernel/tools/ak2-core.sh;


## AnyKernel permissions
# set permissions for included ramdisk files
chmod -R 755 $ramdisk
chmod 644 $ramdisk/sbin/media_profiles.xml


## AnyKernel install
dump_boot;

# begin ramdisk changes

# init.rc
backup_file init.rc;
replace_string init.rc "cpuctl cpu,timer_slack" "mount cgroup none /dev/cpuctl cpu" "mount cgroup none /dev/cpuctl cpu,timer_slack";
append_file init.rc "run-parts" init;

# init.tuna.rc
backup_file init.tuna.rc;
insert_line init.tuna.rc "nodiratime barrier=0" after "mount_all /fstab.tuna" "\tmount ext4 /dev/block/platform/omap/omap_hsmmc.0/by-name/userdata /data remount nosuid nodev noatime nodiratime barrier=0";
append_file init.tuna.rc "dvbootscript" init.tuna;

# init.superuser.rc
if [ -f init.superuser.rc ]; then
  backup_file init.superuser.rc;
  replace_string init.superuser.rc "Superuser su_daemon" "# su daemon" "\n# Superuser su_daemon";
  prepend_file init.superuser.rc "SuperSU daemonsu" init.superuser;
else
  replace_file init.superuser.rc 750 init.superuser.rc;
  insert_line init.rc "init.superuser.rc" after "on post-fs-data" "    import /init.superuser.rc";
fi;

# fstab.tuna
backup_file fstab.tuna;
patch_fstab fstab.tuna /system ext4 options "nodiratime,barrier=0" "nodev,noatime,nodiratime,barrier=0,data=writeback,noauto_da_alloc,discard";
patch_fstab fstab.tuna /cache ext4 options "barrier=0,nomblk_io_submit" "nosuid,nodev,noatime,nodiratime,errors=panic,barrier=0,nomblk_io_submit,data=writeback,noauto_da_alloc";
patch_fstab fstab.tuna /data ext4 options "nomblk_io_submit,data=writeback" "nosuid,nodev,noatime,errors=panic,nomblk_io_submit,data=writeback,noauto_da_alloc";
append_file fstab.tuna "usbdisk" fstab;

# end ramdisk changes

write_boot;

## end install

