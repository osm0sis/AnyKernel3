# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=POCO X3 NFC Miui/Aosp Support
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=surya
device.name2=karna
supported.versions=11-17
'; } # end properties

## AnyKernel file attributes
# set permissions / ownership for included ramdisk files
boot_attributes() {
    set_perm_recursive 0 0 755 644 "$ramdisk/*";
    set_perm_recursive 0 0 750 750 "$ramdisk/init*" "$ramdisk/sbin";
}

# begin build.prop loader
load_build_props() {
    if [ ! -f "/system/build.prop" ] && [ ! -f "/system_root/system/build.prop" ]; then
        mount /system 2>/dev/null || mount /system_root 2>/dev/null
    fi

    if [ -f "/system/build.prop" ]; then
        SYSTEM_BUILD_PROP="/system/build.prop"
    elif [ -f "/system_root/system/build.prop" ]; then
        SYSTEM_BUILD_PROP="/system_root/system/build.prop"
    fi

    if [ -n "$SYSTEM_BUILD_PROP" ]; then
        PROP_MIUI=$(file_getprop "$SYSTEM_BUILD_PROP" ro.miui.ui.version.code)
    fi
} # end build.prop loader

# begin legacy bootargs patch
patch_legacy_bootargs() {
    ui_print " "

    if [ -n "$PROP_MIUI" ]; then
        ui_print "MIUI $PROP_MIUI detected, defaulting to legacy bootargs"
        patch_cmdline init.is_legacy_ebpf init.is_legacy_ebpf=1
        patch_cmdline init.is_legacy_timestamp init.is_legacy_timestamp=1
        return
    fi

    if [ "$ANDROID_VERSION" -lt 15 ]; then
        ui_print "Enabling legacy eBPF bootarg..."
        patch_cmdline init.is_legacy_ebpf init.is_legacy_ebpf=1
    else
        ui_print "Disabling legacy eBPF bootarg..."
        patch_cmdline init.is_legacy_ebpf init.is_legacy_ebpf=0
    fi

    if [ "$ANDROID_VERSION" -lt 13 ]; then
        ui_print "Enabling legacy timestamp bootarg..."
        patch_cmdline init.is_legacy_timestamp init.is_legacy_timestamp=1
    else
        ui_print "Disabling legacy timestamp bootarg..."
        patch_cmdline init.is_legacy_timestamp init.is_legacy_timestamp=0
    fi
} # end legacy bootargs patch

# Android version strings
if [ -f "$AKHOME/android_ver" ]; then
    ANDROID_VERSION=$(cat "$AKHOME/android_ver")
fi

# shell variables
block="/dev/block/bootdevice/by-name/boot";
is_slot_device=0;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

# Apply Image & dts
mv kernels/dtb.img dtb.img
mv kernels/dtbo.img dtbo.img;
mv kernels/Image.gz Image.gz;

## AnyKernel install
dump_boot;
load_build_props;
patch_legacy_bootargs;
write_boot;
## end install
