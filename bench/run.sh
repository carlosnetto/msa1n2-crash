#!/bin/bash
# Micro-benchmark focused on what idle power-saving changes affect:
# CPU C-state wake-up latency, NVMe/PCIe wake latency, plus throughput sanity checks.
#
# Usage: bench/run.sh <output-file>   e.g. bench/run.sh experiments/NN-name/result.txt
# Needs: gcc, 7z (p7zip-full). No root required.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
out="$(realpath -m "$1")"
[ -n "$1" ] || { echo "usage: $0 <output-file>"; exit 1; }
cd "$here"
for p in wakelat nvmelat membw; do [ "$p" -nt "$p.c" ] || gcc -O2 -o "$p" "$p.c"; done
# 4 GiB file read with O_DIRECT (page cache bypassed); must live on the NVMe under test.
[ -f testfile ] || dd if=/dev/urandom of=testfile bs=1M count=4096 status=none

{
echo "=== $1  $(date)  kernel: $(uname -r)"
echo "cmdline: $(sed -E 's/root=UUID=[0-9a-f-]+/root=UUID=<redacted>/' /proc/cmdline)"
echo "load: $(cut -d' ' -f1-3 /proc/loadavg)   nvme ps_max_latency: $(cat /sys/module/nvme_core/parameters/default_ps_max_latency_us)"
echo "cpu0 idle states: $(for s in /sys/devices/system/cpu/cpu0/cpuidle/state*; do printf '%s(%s) ' $(cat $s/name) $([ "$(cat $s/disable)" = 1 ] && echo off || echo on); done)"
echo "--- CPU wake-up latency"
./wakelat 50 5000; ./wakelat 1000 2000; ./wakelat 10000 300
echo "--- NVMe 4K random read latency"
./nvmelat testfile 20000 0; ./nvmelat testfile 100 200
echo "--- Memory"
./membw
echo "--- 7-Zip (MIPS, higher=better)"
echo "1 thread : $(7z b -mmt1 2>/dev/null | awk '/^Tot:/{print $NF}')"
echo "all thr  : $(7z b 2>/dev/null | awk '/^Tot:/{print $NF}')"
} 2>&1 | tee "$out"
