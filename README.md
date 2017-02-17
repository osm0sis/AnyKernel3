----------------------------------------------------------------------------------
AnyKernel2 - Flashable Zip Template for Kernel Releases with Ramdisk Modifications
----------------------------------------------------------------------------------
### by osm0sis @ xda-developers ###

"AnyKernel is a template for an update.zip that can apply any kernel to any ROM, regardless of ramdisk." - Koush

AnyKernel2 pushes the format even further by allowing kernel developers to modify the underlying ramdisk for kernel feature support easily using a number of included command methods along with properties and variables.

A working script based on DirtyV Kernel for Galaxy Nexus (tuna) is included for reference.

## // Properties / Variables ##
```
kernel.string=KernelName by YourName @ xda-developers
do.devicecheck=1
do.initd=1
do.modules=1
do.cleanup=1
do.cleanuponabort=0
device.name1=maguro
device.name2=toro
device.name3=toroplus

block=/dev/block/platform/omap/omap_hsmmc.0/by-name/boot;
is_slot_device=0;
```

__do.devicecheck=1__ specified requires at least device.name1 to be present. This should match ro.product.device or ro.build.product for your device. There is support for up to 5 device.name# properties.

__do.initd=1__ will create the init.d directory in /system/etc/init.d/ and apply 755 permissions.

__do.modules=1__ will push the contents of the module directory to /system/lib/modules/ and apply 644 permissions.

__do.cleanup=0__ will keep the zip from removing it's working directory in /tmp/anykernel - this can be useful if trying to debug in adb shell whether the patches worked correctly.

__do.cleanuponabort=0__ will keep the zip from removing it's working directory in /tmp/anykernel in case of installation abort.

`is_slot_device=1` enables detection of the suffix for the active boot partition on slot-based devices and will add this to the end of the supplied `block=` path.

## // Command Methods ##
```
dump_boot
backup_file <file>
replace_string <file> <if search string> <original string> <replacement string>
replace_section <file> <begin search string> <end search string> <replacement string>
remove_section <file> <begin search string> <end search string>
insert_line <file> <if search string> <before|after> <line match string> <inserted line>
replace_line <file> <line replace string> <replacement line>
remove_line <file> <line match string>
prepend_file <file> <if search string> <patch file>
insert_file <file> <if search string> <before|after> <line match string> <patch file>
append_file <file> <if search string> <patch file>
replace_file <file> <permissions> <patch file>
patch_fstab <fstab file> <mount match name> <fs match type> <block|mount|fstype|options|flags> <original string> <replacement string>
write_boot
```

__"if search string"__ is the string it looks for to decide whether it needs to add the tweak or not, so generally something to indicate the tweak already exists.

Similarly, __"line match string"__ and __"line replace string"__ are the search strings that locate where the modification needs to be made for those commands, __"begin search string"__ and __"end search string"__ are both required to select the first and last lines of the script block to be replaced for replace_section, and __"mount match name"__ and __"fs match type"__ are both required to narrow the _patch_fstab_ command down to the correct entry.

__"before|after"__ requires you simply specify __"before"__ or __"after"__ for the placement of the inserted line, in relation to __"line match string"__.

__"block|mount|fstype|options|flags"__ requires you specify which part (listed in order) of the fstab entry you want to check and alter.

You may also use _ui_print "\<text\>"_ to write messages back to the recovery during the modification process, and _contains "\<string\>" "\<substring\>"_ to simplify string testing logic you might want in your script.

## // Instructions ##

1. Place zImage in the root (dtb should also go here for devices that require a custom one, both will fallback to the original if not included)

2. Place any required ramdisk files in /ramdisk

3. Place any required patch files (generally partial files which go with commands) in /patch

4. Modify the anykernel.sh to add your kernel's name, boot partition location, permissions for included ramdisk files, and use methods for any required ramdisk modifications

5. zip -r9 UPDATE-AnyKernel2.zip * -x README UPDATE-AnyKernel2.zip

If supporting a recovery that forces zip signature verification (like Cyanogen Recovery) then you will need to also sign your zip using the method I describe here:

http://forum.xda-developers.com/android/software-hacking/dev-complete-shell-script-flashable-zip-t2934449

Not required, but any tweaks you can't hardcode into the source should be added with a bootscript.sh like is done in the example provided.


Have fun!
