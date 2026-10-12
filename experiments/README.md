# Experiments

Each folder is one run: what changed, under what conditions, the raw output (`result.txt` or
similar), and an honest verdict, including runs that went wrong or proved nothing.

| # | Date | Change | Conditions | Valid? | Outcome |
|---|---|---|---|---|---|
| [00](00-baseline/) | 2026-10-12 | none (stock) | VMs running | ✅ | Baseline. 10 ms wake ≈ 10 µs; first NVMe read after idle 13–30× slower |
| [01](01-timer-slack-artifact/) | 2026-10-12 | none (stock) | VMs running | ⚠️ partially | Found a measurement bug: 50 µs timer slack hid C-state latency. Fixed in `wakelat.c`. Also shows run-to-run noise |
| [02](02-kernel-params-vms-off/) | 2026-10-12 | `max_cstate=2`, NVMe APST off, ASPM off | **VMs stopped** | ❌ as a comparison | Idle machine: 10 ms wake jumped to ~359 µs (package C-states), throughput +15% (no competing load). Not comparable |
| [03](03-kernel-params-steady-state/) | 2026-10-12 | `max_cstate=2`, NVMe APST off, ASPM off | VMs running, steady | ✅ | **No performance change** vs. baseline (all within noise). Stability verdict pending |

## Running a new experiment

```bash
mkdir experiments/NN-short-name
bench/run.sh experiments/NN-short-name/result.txt
# then write experiments/NN-short-name/README.md: change, conditions, results table, verdict
```

Tips learned so far:
- Run at the **same workload state** as the baseline: VMs up, after boot and JVM warm-up
  (wait until load is back to about 2).
- Single runs are noisy, especially the NVMe idle-gap median (only 100 samples) and p99s. Compare
  against the baseline range, not a single number.
