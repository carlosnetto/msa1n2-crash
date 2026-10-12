# 02 — Kernel parameters, measured with all VMs stopped (not a valid comparison)

- **Date:** 2026-10-12 09:50 CDT (10 min after reboot)
- **Change:** `processor.max_cstate=2 nvme_core.default_ps_max_latency_us=0 pcie_aspm=off`
- **Verified active:** C3 no longer listed in cpuidle; `ps_max_latency_us=0`; params in `/proc/cmdline`
- **Conditions:** **No VMs running** (libvirt doesn't autostart them), load 0.00
- **Raw:** [`result.txt`](result.txt)

## Results compared with the baseline

| Metric | 00 baseline (busy) | 02 (idle machine) |
|---|---|---|
| CPU wake after 10 ms sleep, median / p99 | 10.4 / 21.1 µs | **359 / 601 µs** ❌ |
| CPU wake after 1 ms sleep, median / p99 | 1.8 / 9.9 µs | 1.5 / 4.7 µs |
| NVMe 4K back-to-back, median / p99 / max | 47 / 3,399 / 12,898 µs | 67 / **75** / 263 µs |
| NVMe 4K after 200 ms idle, median | 1,517 µs | 1,118 µs |
| memcpy, 1 thread | 37.9 GB/s | 40.9 GB/s |
| 7-Zip, 1 thread / all threads | 6,900 / 123,933 | 7,989 / 139,891 |

## Interpretation

- **Not comparable with the baseline:** the baseline ran with VMs loading the machine. With
  nothing else running, 7-Zip got the whole CPU (+13–16%), and the NVMe tail latency was low
  because no other disk I/O was competing.
- **The 10 ms wake got 35× worse, despite C3 being disabled.** The likely cause is **package
  C-states**: when *every* core is idle, the firmware can put the whole CPU package into a deep
  sleep, and `processor.max_cstate` doesn't control that. With VMs running, at least one core is
  always busy, so the package never got that far. The NVMe idle-gap read (still about 1.1 ms)
  probably includes the same package wake-up cost.
- This points to the BIOS setting **Power Supply Idle Control → Typical Current Idle** as the
  next step: it limits package-level deep idle.

## Verdict

Discarded as a before/after comparison, but it's a useful finding: an *idle* MS-A1 has
millisecond-scale wake-ups at the package level even with `max_cstate=2`.
