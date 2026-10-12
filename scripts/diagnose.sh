#!/bin/bash
# Post-crash triage: how did previous boots end, and is there anything in the logs?
# Usage: scripts/diagnose.sh [boots_back]   (default 5)
n=${1:-5}

echo "== Machine"
cat /sys/class/dmi/id/{sys_vendor,product_name,bios_version,bios_date} 2>/dev/null | paste -sd' '
grep -m1 'model name' /proc/cpuinfo
for d in /sys/class/nvme/nvme*; do echo "NVMe: $(cat $d/model | xargs) fw=$(cat $d/firmware_rev)"; done
echo "cmdline: $(sed -E 's/root=UUID=[0-9a-f-]+/root=UUID=<redacted>/' /proc/cmdline)"

echo; echo "== Boots"
journalctl --list-boots --no-pager | tail -n $((n+1))

echo; echo "== How each boot ended (clean = 'Journal stopped'; crash = log just stops)"
for b in $(seq -$n -1); do
  k=$(journalctl -b $b -k -n1 --no-pager -g 'Linux version' -o cat 2>/dev/null | awk '{print $3}')
  last=$(journalctl -b $b -n1 --no-pager -o short-iso 2>/dev/null | tail -1 | cut -c1-140)
  echo "[$b] kernel=$k :: $last"
done

echo; echo "== Unclean shutdowns detected by journald"
journalctl --no-pager -o short-iso -g 'corrupted or uncleanly' | grep -v '^--'

echo; echo "== Hardware/kernel error keywords in previous boot"
journalctl -b -1 --no-pager -o short-iso | grep -iE 'mce|machine check|hardware error|out of memory|killed process|watchdog: |lockup|hung_task|blocked for more|i/o error|edac|thermal|nvme.*(timeout|reset)|amdgpu.*(timeout|reset|hang)|pcie.*error|aer' | grep -vE 'Registered|Enabled|Ver: |decoding enabled|_OSC|thermald' | tail -40

echo; echo "== Crash dumps"
ls /var/crash /var/lib/systemd/pstore 2>&1

echo; echo "== CPU idle states (cpu0)"
cat /sys/devices/system/cpu/cpuidle/current_driver
for s in /sys/devices/system/cpu/cpu0/cpuidle/state*; do echo "$(cat $s/name) latency=$(cat $s/latency)us usage=$(cat $s/usage)"; done
echo "nvme default_ps_max_latency_us: $(cat /sys/module/nvme_core/parameters/default_ps_max_latency_us)"
echo "pcie_aspm policy: $(cat /sys/module/pcie_aspm/parameters/policy)"

echo; echo "== sysstat around end of previous boot (CPU / memory)"
end=$(journalctl -b -1 -n1 --no-pager -o short-iso | tail -1 | awk '{print $1}')
day=$(date -d "${end%T*}" +%d 2>/dev/null)
f=/var/log/sysstat/sa$day
[ -f "$f" ] && { sar -u -f "$f" | tail -8; sar -r -f "$f" | tail -8; } || echo "no sysstat file for $day"
