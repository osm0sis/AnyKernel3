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
do.modules=1
do.cleanup=1
do.cleanuponabort=0
device.name1=maguro
device.name2=toro
device.name3=toroplus

block=/dev/block/platform/omap/omap_hsmmc.0/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;
```

__do.devicecheck=1__ specified requires at least device.name1 to be present. This should match ro.product.device or ro.build.product for your device. There is support for up to 5 device.name# properties.

__do.modules=1__ will push the contents of the module directory to the same location relative to root (/) and apply 644 permissions.

__do.cleanup=0__ will keep the zip from removing it's working directory in /tmp/anykernel - this can be useful if trying to debug in adb shell whether the patches worked correctly.

__do.cleanuponabort=0__ will keep the zip from removing it's working directory in /tmp/anykernel in case of installation abort.

`is_slot_device=1` enables detection of the suffix for the active boot partition on slot-based devices and will add this to the end of the supplied `block=` path. Also accepts `auto` for use with broad, device non-specific zips.

`ramdisk_compression=auto` allows automatically repacking the ramdisk with the format detected during unpack, changing `auto` to `gz`, `lzo`, `lzma`, `xz`, `bz2`, `lz4`, or `lz4-l` (for lz4 legacy) instead forces the repack as that format.

## // Command Methods ##
```
dump_boot
split_boot
unpack_ramdisk
backup_file <file>
restore_file <file>
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
patch_cmdline <cmdline entry name> <replacement string>
patch_prop <prop file> <prop name> <new prop value>
repack_ramdisk
flash_boot
write_boot
reset_ak
```

__"if search string"__ is the string it looks for to decide whether it needs to add the tweak or not, so generally something to indicate the tweak already exists. __"cmdline entry name"__ behaves somewhat like this as a match check for the name of the cmdline entry to be changed/added by the _patch_cmdline_ function, followed by the full entry to replace it. __"prop name"__ also serves as a match check in _patch_prop_ for a property in the given prop file, but is only the prop name as the prop value is specified separately.

Similarly, __"line match string"__ and __"line replace string"__ are the search strings that locate where the modification needs to be made for those commands, __"begin search string"__ and __"end search string"__ are both required to select the first and last lines of the script block to be replaced for _replace_section_, and __"mount match name"__ and __"fs match type"__ are both required to narrow the _patch_fstab_ command down to the correct entry.

__"before|after"__ requires you simply specify __"before"__ or __"after"__ for the placement of the inserted line, in relation to __"line match string"__.

__"block|mount|fstype|options|flags"__ requires you specify which part (listed in order) of the fstab entry you want to check and alter.

_dump_boot_ and _write_boot_ are the default method of unpacking/repacking, but for more granular control, or omitting ramdisk changes entirely ("OG AK" mode), these can be separated into _split_boot; unpack_ramdisk_ and _repack_ramdisk; flash_boot_ respectively.

Multi-partition zips can be created by removing the ramdisk and patch folders from the zip and including instead "-files" folders named for the partition (without slot suffix), e.g. boot-files + recovery-files, or kernel-files + ramdisk-files (on some Treble devices). These then contain zImage, and ramdisk, patch, etc. subfolders for each partition. To setup for the next partition, simply set `block=` and `ramdisk_compression=` for the new target partition and use the _reset_ak_ command.

_backup_file_ may be used for testing to ensure ramdisk changes are made correctly, transparency for the end-user, or in a ramdisk-only "mod" zip. In the latter case _restore_file_ could also be used to create a "restore" zip to undo the changes, but should be used with caution since the underlying patched files could be changed with ROM/kernel updates.

You may also use _ui_print "\<text\>"_ to write messages back to the recovery during the modification process, and _file_getprop "\<file\>" "\<property\>"_ and _contains "\<string\>" "\<substring\>"_ to simplify string testing logic you might want in your script.

## // Binary Inclusion ##

The AK2 repo includes my latest static ARM builds of `mkbootimg`, `unpackbootimg`,`busybox`, `xz` and `lz4` by default to keep the basic package small. Builds for other architectures and optional binaries (see below) are available from my latest AIK-mobile and FlashIt packages, respectively, here:

https://forum.xda-developers.com/showthread.php?t=2073775 (Android Image Kitchen thread)  
https://forum.xda-developers.com/showthread.php?t=2239421 (Odds and Ends thread)

Optional supported binaries which may be placed in /tools to enable built-in expanded functionality are as follows:
* `mkbootfs` - for broken recoveries, or, booted flash support for a script/app via bind mount to /tmp (deprecated/use with caution)
* `flash_erase`, `nanddump`, `nandwrite` - MTD block device support for devices where the `dd` command is not sufficient
* `pxa-unpackbootimg`, `pxa-mkbootimg` - Samsung/Marvell PXA1088/PXA1908 boot.img format variant support
* `dumpimage`, `mkimage` - DENX U-Boot uImage format support
* `unpackelf` - Sony ELF kernel.elf format support, repacking as AOSP standard boot.img for unlocked bootloaders
* `elftool`, `unpackelf` - Sony ELF kernel.elf format support, repacking as ELF for older Sony devices
* `mkmtkhdr` - MTK device boot image section headers support
* `futility` + `chromeos` test keys directory - Google ChromeOS signature support
* `BootSignature_Android.jar` + `avb` keys directory - Google Android Verified Boot (AVB) signature support
* `blobpack` - Asus SignBlob signature support
* `dhtbsign` - Samsung/Spreadtrum DHTB signature support
* `rkcrc` - Rockchip KRNL ramdisk image support

## // Instructions ##

1. Place zImage in the root (dtb and/or dtbo should also go here for devices that require custom ones, each will fallback to the original if not included)

2. Place any required ramdisk files in /ramdisk and modules in /modules (with the full path like /modules/system/lib/modules)

3. Place any required patch files (generally partial files which go with commands) in /patch

4. Modify the anykernel.sh to add your kernel's name, boot partition location, permissions for included ramdisk files, and use methods for any required ramdisk modifications (optionally, also place banner and/or version files in the root to have these displayed during flash)

5. `zip -r9 UPDATE-AnyKernel2.zip * -x README.md UPDATE-AnyKernel2.zip`

If supporting a recovery that forces zip signature verification (like Cyanogen Recovery) then you will need to also sign your zip using the method I describe here:

http://forum.xda-developers.com/android/software-hacking/dev-complete-shell-script-flashable-zip-t2934449

Not required, but any tweaks you can't hardcode into the source (best practice) should be added with an additional init.tweaks.rc or bootscript.sh to minimize the necessary ramdisk changes.

It is also extremely important to note that for the broadest AK2 compatibility it is always better to modify a ramdisk file rather than replace it.

If running into trouble when flashing an AK2 zip, the suffix -debugging may be added to the zip's filename to enable creation of a debug .tgz of /tmp for later examination while booted or on desktop.

For further support and usage examples please see the AnyKernel2 XDA thread: https://forum.xda-developers.com/showthread.php?t=2670512

Have fun!
