   #Cpu Tweaks
   chmod 644 /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
   echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
   chmod 644 /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
   echo 343000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
   chmod 644 /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
   echo 1690000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq

   chmod 644 /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
   echo performance > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
   chmod 644 /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
   echo 343000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
   chmod 644 /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq
   echo 1690000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq
   
   #Samsung Hotplug
   chmod 644 /sys/power/cpuhotplug/enable
   echo 0 > /sys/power/cpuhotplug/enable
  
   #Gpu Tweaks
   chmod 644 /sys/devices/11400000.mali/max_clock
   echo 1146 > /sys/devices/11400000.mali/max_clock
   chmod 644 /sys/devices/11400000.mali/min_clock
   echo 1146 > /sys/devices/11400000.mali/min_clock
   chmod 644 /sys/devices/11400000.mali/power_policy
   echo always_on > /sys/devices/11400000.mali/power_policy
   #chmod 644 /sys/devices/11400000.mali/dvfs_governor
   #echo always_on > /sys/devices/11400000.mali/dvfs_governor

   #Internal I/O Scheduler tweaks
   chmod 644 /sys/block/mmcblk0/queue/scheduler
   echo "maple" > /sys/block/mmcblk0/queue/scheduler
   chmod 644 /sys/block/mmcblk0/queue/read_ahead_kb
   echo "1024" > /sys/block/mmcblk0/queue/read_ahead_kb

   #External I/O Scheduler tweaks
   chmod 644 /sys/block/mmcblk1/queue/scheduler
   echo "maple" > /sys/block/mmcblk1/queue/scheduler
   chmod 644 /sys/block/mmcblk1/queue/read_ahead_kb
   echo "1024" > /sys/block/mmcblk1/queue/read_ahead_kb
   
   #Misc
   chmod 644 /sys/module/sync/parameters/fsync_enabled
   chmod 644 /sys/kernel/dyn_fsync/Dyn_fsync_active
   chmod 644 /sys/kernel/sched/gentle_fair_sleepers
   chmod 644 /sys/kernel/sched/arch_power
   echo "N" > /sys/module/sync/parameters/fsync_enabled
   echo "0" > /sys/kernel/dyn_fsync/Dyn_fsync_active
   echo "0" > /sys/kernel/sched/gentle_fair_sleepers
   echo "0" > /sys/kernel/sched/arch_power
