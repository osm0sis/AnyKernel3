#!/sbin/sh

android_ver=<ANDROID_VER>

ui_print " "
ui_print " Would you like to skip vol keys?"
ui_print "   Vol Up = Yes, Vol Down = No"
if $VKSEL; then
  ui_print " Exiting script to skip vol keys....."
  ui_print " Continuing Installation....."
  sleep 2
  SKIP=1
  sed -i "s|<selinux>|""|" $home/anykernel.sh
else
  ui_print " "
  ui_print " Continuing vol key install..."
  sleep 2
  SKIP=0
fi
if [ $SKIP == 0 ]; then
  ui_print " "
  ui_print " Do you want to enable Quad DAC force advanced mode?"
  ui_print "   Vol Up = Yes, Vol Down = No"
  if $VKSEL; then
    ui_print " Enabling Quad DAC Force advanced mode"
    sed -i 's/force_advanced_mode 0/force_advanced_mode 1/' $home/ramdisk/init.jolla-kernel.rc; 
  else
    ui_print " Disabling Quad DAC Force advanced mode"
    sed -i 's/force_advanced_mode 1/force_advanced_mode 0/' $home/ramdisk/init.jolla-kernel.rc;
  fi
    
  ui_print " "
  ui_print " Do you want to enable screen off volume control?"
  ui_print "   Vol Up = Yes, Vol Down = No"
  if $VKSEL; then
    ui_print " Enabling SOVC"
    sed -i 's/scroff_volctr 0/scroff_volctr 1/' $home/ramdisk/init.jolla-kernel.rc;
  else
    ui_print " Disabling SOVC"
    sed -i 's/scroff_volctr 1/scroff_volctr 0/' $home/ramdisk/init.jolla-kernel.rc;
  fi

  ui_print " "
  ui_print " Do you want to enable dynamic fsync?"
  ui_print "   Vol Up = Yes, Vol Down = No"
  if $VKSEL; then
    ui_print " Enabling Dynamic Fsync"
    sed -i 's/Dyn_fsync_active 0/Dyn_fsync_active 1/' $home/ramdisk/init.jolla-kernel.rc;
  else
    ui_print " Disabling Dynamic Fsync"
    sed -i 's/Dyn_fsync_active 1/Dyn_fsync_active 0/' $home/ramdisk/init.jolla-kernel.rc;
  fi

  ui_print " "
  ui_print " Do you want to enable kgsl power control limit?"
  ui_print "   Vol Up = Yes, Vol Down = No"
  if $VKSEL; then
    ui_print " Enabling KGSL power control"
    sed -i 's/kgsl_pwrctrl_limit_enable 0/kgsl_pwrctrl_limit_enable 1/' $home/ramdisk/init.jolla-kernel.rc;
  else
    ui_print " Disabling KGSL power control"
    sed -i 's/kgsl_pwrctrl_limit_enable 1/kgsl_pwrctrl_limit_enable 0/' $home/ramdisk/init.jolla-kernel.rc;
  fi

  ui_print " "
  ui_print " Do you want to enable kcal_fix_yellow?"
  ui_print "   Vol Up = Yes, Vol Down = No"
  if $VKSEL; then
    ui_print " Enabling Kcal Yellow Fix"
  else
    ui_print " Disabling Kcal Yellow Fix"
    sed -i "/kcal/d" $home/ramdisk/init.jolla-kernel.rc
  fi
fi
  ui_print " "
  ui_print " Select Sepolicy"
  ui_print " Vol+ = Enforcing, Vol- = Permissive"
  if $VKSEL; then
    ui_print " Setting kernel to enforcing..."
    sed -i "s|<selinux>|no|" $home/anykernel.sh
  else
    ui_print " Setting kernel to permissive..."
    sed -i "s|<selinux>|yes|" $home/anykernel.sh
  fi