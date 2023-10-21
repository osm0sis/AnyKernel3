----------------------------------------------------------------------------------
AnyKernel3 - Flashable Zip Template for Kernel Releases with Ramdisk Modifications
----------------------------------------------------------------------------------
### by osm0sis @ xda-developers ###

"AnyKernel is a template for an update.zip that can apply any kernel to any ROM, regardless of ramdisk." - Koush

AnyKernel2 pushed the format further by allowing kernel developers to modify the underlying ramdisk for kernel feature support easily using a number of included command methods along with properties and variables to customize the installation experience to their kernel. AnyKernel3 adds the power of topjohnwu's magiskboot for wider format support by default, and to automatically detect and retain Magisk root by patching the new Image.*-dtb as Magisk would.

_A script based on Galaxy Nexus (tuna) is included for reference. Everything to edit is self-contained in __anykernel.sh__._

## // Properties / Variables ##
```
kernel.string=KernelName by YourName @ xda-developers
do.devicecheck=1
do.modules=1
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=maguro
device.name2=toro
device.name3=toroplus
device.name4=tuna
supported.versions=6.0 - 7.1.2
supported.patchlevels=2019-07 -
supported.vendorpatchlevels=2013-07

block=/dev/block/platform/omap/omap_hsmmc.0/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;
```

__do.devicecheck=1__ specified requires at least device.name1 to be present. This should match ro.product.device, ro.build.product, ro.product.vendor.device or ro.vendor.product.device from the build.prop files for your device. There is support for as many device.name# properties as needed. You may remove any empty ones that aren't being used.

__do.modules=1__ will push the .ko contents of the modules directory to the same location relative to root (/) and apply correct permissions. On A/B devices this can only be done to the active slot.

__do.systemless=1__ (with __do.modules=1__) will instead push the full contents of the modules directory to create a simple "ak3-helper" Magisk/KernelSU module, allowing developers to effectively replace system files, including .ko files. If the current kernel is changed then the kernel helper module automatically removes itself to prevent conflicts.

__do.cleanup=0__ will keep the zip from removing its working directory in /tmp/anykernel (by default) - this can be useful if trying to debug in adb shell whether the patches worked correctly.

__do.cleanuponabort=0__ will keep the zip from removing its working directory in /tmp/anykernel (by default) in case of installation abort.

__supported.versions=__ will match against ro.build.version.release from the current ROM's build.prop. It can be set to a list or range. As a list of one or more entries, e.g. `7.1.2` or `8.1.0, 9` it will look for exact matches, as a range, e.g. `7.1.2 - 9` it will check to make sure the current version falls within those limits. Whitespace optional, and supplied version values should be in the same number format they are in the build.prop value for that Android version.

__supported.patchlevels=__ and __supported.vendorpatchlevels=__ will match against ro.build.version.security_patch and ro.vendor.build.security_patch, respectively, from the current system/vendor build.prop. They can be set as a closed or open-ended range of dates in the format YYYY-MM, whitespace optional, e.g. `2019-04 - 2019-06`, `2019-04 -` or `- 2019-06` where the last two examples show setting a minimum or maximum.

`block=auto` instead of a direct block filepath enables detection of the device boot partition for use with broad, device non-specific zips. Also accepts any partition filename (from by-name), e.g. `boot`, `recovery` or `vendor_boot`.

`is_slot_device=1` enables detection of the suffix for the active boot partition on slot-based devices and will add this to the end of the supplied `block=` path. Also accepts `auto` for use with broad, device non-specific zips.

`ramdisk_compression=auto` allows automatically repacking the ramdisk with the format detected during unpack. Changing `auto` to `gz`, `lzo`, `lzma`, `xz`, `bz2`, `lz4`, or `lz4-l` (for lz4 legacy) instead forces the repack as that format, and using `cpio` or `none` will (attempt to) force the repack as uncompressed.

`patch_vbmeta_flag=auto` allows automatically using the default AVBv2 vbmeta flag on repack, and use the Magisk configuration Canary 23016+. Set to `0` forces keeping whatever is in the original AVBv2 flags, and set to `1` forces patching the flag (only necessary on few devices).

`customdd="<arguments>"` may be added to allow specifying additional dd parameters for devices that need to hack their kernel directly into a large partition like mmcblk0, or force use of dd for flashing.

`slot_select=active|inactive` may be added to allow specifying the target slot. If omitted the default remains `active`.

`no_block_display=1` may be added to disable output of the detected final used partition+slot path for zips which choose to include their own custom output instead.

`no_magisk_check=1` may be added to disable detection of Magisk and related kernel/dtb repatching for special zips which don't require that.

## // Command Methods ##
```
ui_print "<text>" [...]
abort ["<text>" [...]]
contains <string> <substring>
file_getprop <file> <property>

set_perm <owner> <group> <mode> <file> [<file2> ...]
set_perm_recursive <owner> <group> <dir_mode> <file_mode> <dir> [<dir2> ...]

dump_boot
split_boot
unpack_ramdisk

backup_file <file>
restore_file <file>
replace_string <file> <if search string> <original string> <replacement string> <scope>
replace_section <file> <begin search string> <end search string> <replacement string>
remove_section <file> <begin search string> <end search string>
insert_line <file> <if search string> <before|after> <line match string> <inserted line>
replace_line <file> <line replace string> <replacement line> <scope>
remove_line <file> <line match string> <scope>
prepend_file <file> <if search string> <patch file>
insert_file <file> <if search string> <before|after> <line match string> <patch file>
append_file <file> <if search string> <patch file>
replace_file <file> <permissions> <patch file>
patch_fstab <fstab file> <mount match name> <fs match type> block|mount|fstype|options|flags <original string> <replacement string>
patch_cmdline <cmdline entry name> <replacement string>
patch_prop <prop file> <prop name> <new prop value>
patch_ueventd <ueventd file> <device node> <permissions> <chown> <chgrp>

repack_ramdisk
flash_boot
flash_generic <partition name>
write_boot

reset_ak [keep]
setup_ak
```

__"if search string"__ is the string it looks for to decide whether it needs to add the tweak or not, so generally something to indicate the tweak already exists. __"cmdline entry name"__ behaves somewhat like this as a match check for the name of the cmdline entry to be changed/added by the _patch_cmdline_ function, followed by the full entry to replace it. __"prop name"__ also serves as a match check in _patch_prop_ for a property in the given prop file, but is only the prop name as the prop value is specified separately.

Similarly, __"line match string"__ and __"line replace string"__ are the search strings that locate where the modification needs to be made for those commands, __"begin search string"__ and __"end search string"__ are both required to select the first and last lines of the script block to be replaced for _replace_section_, and __"mount match name"__ and __"fs match type"__ are both required to narrow the _patch_fstab_ command down to the correct entry.

__"scope"__ may be specified as __"global"__ to force all instances of the string/line targeted by _replace_string_, _replace_line_ or _remove_line_ to be replaced/removed accordingly. Omitted or set to anything else and it will perform the default first-match action.

__"before|after"__ requires you simply specify __"before"__ or __"after"__ for the placement of the inserted line, in relation to __"line match string"__.

__"block|mount|fstype|options|flags"__ requires you specify which part (listed in order) of the fstab entry you want to check and alter.

_dump_boot_ and _write_boot_ are the default method of unpacking/repacking, but for more granular control, or omitting ramdisk changes entirely ("OG AK" mode), these can be separated into _split_boot; unpack_ramdisk_ and _repack_ramdisk; flash_boot_ respectively. _flash_generic_ can be used to flash an image to the corresponding partition. It is automatically included for dtbo, system_dlkm and vendor_dlkm in _write_boot_ but can be called separately if using "OG AK" mode or creating a simple partition flashing only zip.

Multi-partition zips can be created by removing the ramdisk and patch folders from the zip and including instead "-files" folders named for the partition (without slot suffix), e.g. boot-files + recovery-files, or kernel-files + ramdisk-files (on some Treble devices). These then contain Image.gz, and ramdisk, patch, etc. subfolders for each partition. To setup for the next partition, simply set `block=` (without slot suffix) and `ramdisk_compression=` for the new target partition and use the _reset_ak_ command.

Similarly, multi-slot zips can be created with the normal zip layout for the active (current) slot, then resetting for the inactive slot by setting `block=` (without slot suffix) again, `slot_select=inactive` and `ramdisk_compression=` for the target slot and using the _reset_ak keep_ command, which will retain the patch and any added ramdisk files for the next slot.

_backup_file_ may be used for testing to ensure ramdisk changes are made correctly, transparency for the end-user, or in a ramdisk-only "mod" zip. In the latter case _restore_file_ could also be used to create a "restore" zip to undo the changes, but should be used with caution since the underlying patched files could be changed with ROM/kernel updates.

You may also use _ui_print "\<text\>"_ to write messages back to the recovery during the modification process, _abort "\<text>"_ to abort with optional message, and _file_getprop "\<file\>" "\<property\>"_ and _contains "\<string\>" "\<substring\>"_ to simplify string testing logic you might want in your script.

## // Binary Inclusion ##

The AK3 repo includes current ARM builds of `magiskboot`, `magiskpolicy`, `lptools_static`, `httools_static`, `fec`, `snapshotupdater_static` and `busybox` by default to keep the basic package small. Builds for other architectures and optional binaries (see below) are available from the latest Magisk zip, or my latest AIK-mobile and FlashIt packages, respectively, here:

https://forum.xda-developers.com/t/tool-android-image-kitchen-unpack-repack-kernel-ramdisk-win-android-linux-mac.2073775/ (Android Image Kitchen thread)  
https://forum.xda-developers.com/t/tools-zips-scripts-osm0sis-odds-and-ends-multiple-devices-platforms.2239421/ (Odds and Ends thread)

Optional supported binaries which may be placed in /tools to enable built-in expanded functionality are as follows:
* `mkbootfs` - for broken recoveries, or, booted flash support for a script/app via bind mount to /tmp (deprecated/use with caution)
* `flash_erase`, `nanddump`, `nandwrite` - MTD block device support for devices where the `dd` command is not sufficient
* `dumpimage`, `mkimage` - DENX U-Boot uImage format support
* `mboot` - Intel OSIP Android image format support
* `unpackelf`, `mkbootimg` - Sony ELF kernel.elf format support, repacking as AOSP standard boot.img for unlocked bootloaders
* `elftool` (with `unpackelf`) - Sony ELF kernel.elf format support, repacking as ELF for older Sony devices
* `mkmtkhdr` (with `unpackelf`) - MTK device boot image section headers support for Sony devices
* `futility` + `chromeos` test keys directory - Google ChromeOS signature support
* `boot_signer-dexed.jar` (deprecated) + `avb` keys directory - Google Android Verified Boot 1.0 (AVBv1) custom signature support
* `rkcrc` - Rockchip KRNL ramdisk image support

Optionally moving ARM builds to tools/arm and putting x86 builds in tools/x86 will enable architecture detection for use with broad, device non-specific zips.

## // Instructions ##

1. Place final kernel build product, e.g. Image.gz-dtb or zImage to name a couple, in the zip root (any separate dt, dtb or recovery_dtbo, dtbo, system_dlkm and/or vendor_dlkm should also go here for devices that require custom ones, each will fallback to the original if not included)

2. Place any required ramdisk files in /ramdisk (/vendor_ramdisk for simple multi-partition vendor_boot v3 support) and module files in /modules (with the full path like /modules/system/lib/modules)

3. Place any required patch files (generally partial files which go with AK3 file editing commands) in /patch (/vendor_patch for simple multi-partition vendor_boot v3 support)

4. Modify the anykernel.sh to add your kernel's name, boot partition location, permissions for any added ramdisk files, and use methods for any required ramdisk modifications (optionally, also place banner and/or version files in the root to have these displayed during flash)

5. `zip -r9 UPDATE-AnyKernel3.zip * -x .git README.md *placeholder`

_The LICENSE file must remain in the final zip to comply with licenses for binary redistribution and the license of the AK3 scripts._

If supporting a recovery that forces zip signature verification (like Cyanogen Recovery) then you will need to also sign your zip using the method I describe here:

https://forum.xda-developers.com/t/dev-template-complete-shell-script-flashable-zip-replacement-signing-script.2934449/

Not required, but any tweaks you can't hardcode into the source (best practice) should be added with an additional init.tweaks.rc or bootscript.sh to minimize the necessary ramdisk changes. On newer devices Magisk allows these within /overlay.d - see examples.

It is also extremely important to note that for the broadest AK3 compatibility it is always better to modify a ramdisk file rather than replace it.

___If running into trouble when flashing an AK3 zip, the suffix -debugging may be added to the zip's filename to enable creation of a debug .tgz of /tmp for later examination while booted or on desktop.___

## // Staying Up-To-Date ##

Now that you've got a ready zip for your device, you might be wondering how to keep it up-to-date with the latest AnyKernel commits. AnyKernel2 and AnyKernel3 have been painstakingly developed to allow you to just drop in the latest update-binary and tools directory and have everything "just work" for beginners not overly git or script savvy, but the best practice way is as follows:

1. Fork my AnyKernel3 repo on GitHub

2. `git clone https://github.com/<yourname>/AnyKernel3`

3. `git remote add upstream https://github.com/osm0sis/AnyKernel3`

4. `git checkout -b <devicename>`

5. Set it up like your <devicename> zip (i.e. remove any folders you don't use like ramdisk or patch, delete README.md, and add your anykernel.sh and optionally your Image.*-dtb if you want it up there) then commit all those changes

6. `git push --set-upstream origin <devicename>`

7. `git checkout master` then repeat steps 4-6 for any other devices you support

Then you should be able to `git pull upstream master` from your master branch and either merge or cherry-pick the new AK3 commits into your device branches as needed.

___For further support and usage examples please see the AnyKernel3 XDA thread:___ _https://forum.xda-developers.com/t/dev-template-anykernel3-easily-mod-rom-ramdisk-pack-image-gz-flashable-zip.2670512/_

__Have fun!__
