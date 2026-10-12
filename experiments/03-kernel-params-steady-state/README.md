# 03 — Kernel parameters, VMs in steady state ✅ valid comparison

- **Date:** 2026-10-12 10:02 CDT (22 min after reboot)
- **Change:** `processor.max_cstate=2 nvme_core.default_ps_max_latency_us=0 pcie_aspm=off`
- **Verified active:** C3 no longer listed in cpuidle; `ps_max_latency_us=0`
- **Conditions:** 3 VMs running (a different set from the baseline), after their boot and JVM JIT
  warm-up. Load was 2.54 at the start of the run, versus about 2 for the baseline (before 7-Zip pushed it up).
- **Raw:** [`result.txt`](result.txt)

## Results compared with the baseline

Baseline range = min–max across the three stock runs (00 and the two runs in 01).

| Metric | Baseline (stock) | 03 (params) | Change |
|---|---|---|---|
| CPU wake after 10 ms sleep, median | 10.0–10.8 µs | 11.4 µs | none |
| CPU wake after 1 ms sleep, median | 1.7–1.8 µs | 1.7 µs | none |
| NVMe 4K back-to-back, median | 47–50 µs | 47.7 µs | none |
| NVMe 4K back-to-back, p99 | 2.1–3.4 ms | 2.1 ms | none (within noise) |
| NVMe 4K after 200 ms idle, median | 0.61–1.52 ms | 0.58 ms | at the low end of the noise range |
| memcpy, 1 thread | 37.6–37.9 GB/s | 37.1 GB/s | −2% (noise) |
| 7-Zip, 1 thread | 6,695–6,900 | 6,761 | none |
| 7-Zip, all threads | 123,933–125,495 | 124,693 | none |

## Interpretation

- **No measurable performance cost or gain** under the real workload. The parameters are
  essentially free in performance terms, so their only value is **stability**, which can only be
  judged over weeks (freezes came every 1–4 weeks).
- **Disabling C3 didn't change wake latency** (about 10 µs either way). The remaining cost comes
  from C2 (rated 18 µs exit) and the scheduler, so the "deepest" C-state wasn't the main source
  of wake delay on this box.
- **The NVMe idle-gap penalty is still there** (~0.6 ms) with APST and ASPM disabled. So it isn't
  the SSD's OS-controlled power states. It's more likely CPU/package wake-up plus the drive's
  internal behaviour.
- The NVMe back-to-back p99 of about 2 ms comes from contention with the VMs' own disk I/O, both
  before and after.
- **Not measured:** power draw (RAPL counters need root). Expect a few watts more at idle.

## Verdict

Keep the parameters: no performance downside was found. Effectiveness against the freezes is
**unknown until about 4+ weeks without a freeze** (see the incident log in the top-level README).
