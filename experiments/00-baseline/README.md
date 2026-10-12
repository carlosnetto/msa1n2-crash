# 00 — Baseline (stock settings)

- **Date:** 2026-10-12 09:32 CDT
- **Kernel cmdline:** stock (`quiet splash`)
- **State:** C1–C3 enabled, NVMe APST on (`ps_max_latency_us=100000`), ASPM default policy
- **Conditions:** VMs running (pre-reboot set). Load went from about 2 to 12 during the run, because the
  7-Zip runs from experiment 01 had just finished.
- **Raw:** [`result.txt`](result.txt)

## Results

| Metric | Value |
|---|---|
| CPU wake after 50 µs / 1 ms / 10 ms sleep (median) | 1.3 / 1.8 / **10.4 µs** |
| NVMe 4K read back-to-back, median / p99 / max | 47 µs / 3,399 µs / 12,898 µs |
| NVMe 4K read after 200 ms idle, median | **1,517 µs** |
| memcpy, 1 thread | 37.9 GB/s |
| 7-Zip, 1 thread / all threads | 6,900 / 123,933 MIPS |

## Observations

- The longer the CPU sleeps, the slower it wakes: about 10 µs after a 10 ms sleep, because cores
  reach C3 (CC6, rated 350 µs exit latency).
- After an idle gap, the first NVMe read is **13–30× slower** than back-to-back reads. That is
  APST/ASPM wake cost.
- Across three baseline runs (the other two are in [01](../01-timer-slack-artifact/)), the
  throughput numbers vary by about ±2%, and the NVMe idle-gap median varies between 610 and
  1,517 µs (only 100 samples).
