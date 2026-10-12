# 01 — Measurement bug: timer slack hid C-state latency

- **Date:** 2026-10-12 09:29–09:32 CDT
- **Kernel cmdline:** stock
- **Raw:** [`run-1-with-slack.txt`](run-1-with-slack.txt), [`run-2-with-slack.txt`](run-2-with-slack.txt),
  [`wakelat-without-slack.txt`](wakelat-without-slack.txt)

## What happened

The first version of `wakelat` reported a wake-up overshoot of about 51 µs for every sleep length
(50 µs, 1 ms and 10 ms). That flat number is Linux's default **timer slack** of 50 µs for normal
threads: the kernel is allowed to fire timers up to 50 µs late so it can batch wake-ups, and that
delay hid the C-state exit latency entirely.

## Fix

`prctl(PR_SET_TIMERSLACK, 1)` at the start of `wakelat` (now in `bench/wakelat.c`).

| Sleep | Overshoot with slack (median) | Without slack (median, 2 runs) |
|---|---|---|
| 50 µs | 51.1 µs | 1.3 / 10.6 µs |
| 1 ms | 51.4 µs | 1.8 / 1.7 µs |
| 10 ms | 61.5 µs | **10.0 / 10.8 µs** |

## Takeaways

- Wake-latency tests that don't disable timer slack (or run as SCHED_FIFO) measure the
  slack, not the hardware.
- The two runs here also measure noise: NVMe back-to-back p99 ranged from 2.1 to 2.6 ms, and
  7-Zip varied by about 1%. The NVMe and 7-Zip numbers from these runs are valid.
