# Minisforum MS-A1 random hard freezes (Ryzen 9 9950X, Linux)

Notes, scripts and benchmarks from investigating silent hard freezes on a
**Minisforum MS-A1** running Ubuntu 24.04 (HWE kernel 7.0) as an always-on
KVM/Kubernetes host. Kept here so the investigation can be resumed later, and in
case it helps other MS-A1 / MS-A2 owners.

> **Status (2026-10-12):** mitigation applied (kernel parameters below),
> monitoring for recurrence. Root cause not yet confirmed.

## Machine

| Item | Value |
|---|---|
| Box | Minisforum MS-A1 (board A5WSR), BIOS **1.12** (2025-07-02), latest available as of 2026-10 |
| CPU | AMD Ryzen 9 9950X (16C/32T), iGPU Raphael (`1002:13c0`), BIOS-capped to roughly 100 W |
| RAM | ~96 GB DDR5 (2 SO-DIMMs) |
| Disk | Samsung 990 PRO 2 TB, fw `8B2QJXD7` |
| OS | Ubuntu 24.04 (Lubuntu), kernel `7.0.0-38-generic` |
| Workload | libvirt VMs running Kubernetes / Java services, 24/7, headless (accessed over SSH) |

## Symptom

The machine freezes completely and needs a power cycle. **Nothing is logged**:
there's no panic, oops, MCE, OOM, GPU or NVMe error, and no pstore or kdump
output. The journal simply stops, and the next boot reports
`system.journal corrupted or uncleanly shut down`.

Unclean shutdowns found in the journal: **2026-08-28, 08-31, 09-25, 10-12**.
They happened under three different kernels (7.0.0-30, -34 and -38), so they
are not a regression in one kernel version.

The 2026-10-12 freeze happened at 07:30 while the system was ~94% idle
(load ~2 on 32 threads, 44% RAM, no swap; data from sysstat). The last log
lines are routine cron and anacron entries.

## Diagnosis reasoning

A freeze with no logs at **low load**, every few weeks, on a Ryzen system points
to idle power management or hardware rather than the OS:

1. **CPU deep C-states** (the known "Ryzen idle freeze"). The `acpi_idle` driver
   exposes C1 (1 µs), C2 (18 µs) and C3 (350 µs), and C3 was entered about
   2 million times per core in a few hours. Note that an always-on Kubernetes
   host is still "idle" at the microsecond scale.
2. **NVMe APST** (autonomous power-state transitions): if the drive fails to
   wake up, the root disk disappears and nothing can be logged.
3. **PCIe ASPM** (link power management): a link that fails to wake up causes
   the same kind of hang.
4. **Memory** (2×48 GB DDR5, EXPO): rare silent freezes are typical of
   marginal RAM.
5. **iGPU (amdgpu)**: idle hangs are possible even with no monitor attached.
   No MS-A1-specific reports were found.

`scripts/diagnose.sh` reproduces all of the log checks.

## What others report (web research, 2026-10)

- **MS-A1 + 96 GB, random reboots at idle, no logs.** NVMe/ASPM parameters,
  `amd_pstate=passive` and memtest did not fix it. Minisforum replaced the unit
  and the **replacement crashed too**. Closed without a root cause.
  [Level1Techs](https://forum.level1techs.com/t/minisforum-ms-a1-running-proxmox-randomly-reboots/216366)
- **MS-A1 lockups on resume from suspend** (Debian), a different trigger.
  [Level1Techs](https://forum.level1techs.com/t/minisforum-ms-a1-debian-12-sleep-crashes-and-turns-hot/223374)
- **MS-A1 with a 9950X:** early BIOS needed a manual TDP limit; reports of black
  screens and shutdowns without enough cooling.
  [Level1Techs](https://forum.level1techs.com/t/ms-a1-barebone-build-no-boot/215906),
  [TechPowerUp](https://www.techpowerup.com/329829/minisforum-ms-a1-mini-pc-finally-gets-the-16-core-ryzen-9-9950x-treatment),
  [Notebookcheck](https://www.notebookcheck.net/Minisforum-MS-A1-refresh-released-with-curious-AMD-Ryzen-9-9950X-processor-change.932255.0.html)
- **MS-A2 (9955HX), spontaneous reboots with no logs and no kdump** on newer
  kernels (6.17, 7.0). Only pinning kernel 6.14.8 helped.
  [Proxmox forum](https://forum.proxmox.com/threads/spontaneous-reboots-on-minisforum-ms-a2-with-6-17-and-later-6-14.181084/)
- **MS-A2 BIOS 1.03** broke VM passthrough.
  [Proxmox forum](https://forum.proxmox.com/threads/lockout-of-minisforum-ms-a2-brick-warning-after-1-03-update-of-9955hx.184834/)
- **MS-01 / MS-02** hard hangs every few weeks with no logs; helped by BIOS
  updates or by disabling C-states and ASPM.
  [XCP-ng](https://xcp-ng.org/forum/topic/9500/minisforum-ms-01-unstable-and-hangs-running-xcp-ng-8-3),
  [Frigate](https://github.com/blakeblackshear/frigate/discussions/21816)
- Minisforum lists **BIOS 1.12** as the newest MS-A1 BIOS, with no release
  notes. [Minisforum support](https://www.minisforum.com/pages/product-info)

## Action plan

Change one thing at a time and give each change a couple of weeks (the
freezes come every 1–4 weeks).

| # | Action | Status |
|---|---|---|
| 1 | Kernel params `processor.max_cstate=2 nvme_core.default_ps_max_latency_us=0 pcie_aspm=off` | **Applied 2026-10-12**; no performance cost ([exp 03](experiments/03-kernel-params-steady-state/)) |
| 2 | BIOS: *Power Supply Idle Control* set to **Typical Current Idle**; **EXPO off**; optionally *UMA Frame Buffer* set to 512M (frees ~1.5 GB) | To do |
| 3 | Kernel param `modprobe.blacklist=amdgpu` (headless box; console falls back to the firmware framebuffer) | If it freezes again |
| 4 | memtest86+ overnight (already in the GRUB menu) | If it freezes again |
| 5 | Contact Minisforum support / RMA | If all of the above fail |
| – | BIOS update | Not possible: 1.12 is the latest |

Optional extras: install `linux-crashdump` (kdump) or set up `netconsole` to
capture output if the kernel panics, and run
`systemctl set-default multi-user.target` (no point running a desktop on a
headless host).

### What the kernel parameters do

| Parameter | Effect | Cost |
|---|---|---|
| `processor.max_cstate=2` | Cores never enter C3 (the deepest state: 350 µs exit, "CC6"). With `acpi_idle` only C1–C3 exist, so `=5` would have no effect. | Somewhat higher idle power and temperature |
| `nvme_core.default_ps_max_latency_us=0` | Disables NVMe APST; the SSD never enters deep sleep (the default allows states up to 100 ms exit latency) | ~1–3 W, slightly warmer SSD |
| `pcie_aspm=off` | PCIe links never enter L0s/L1 low-power states | A few W |

Package-level C-states (the whole CPU sleeping when every core is idle) are
controlled by firmware, not by `max_cstate`. That is what *Power Supply Idle
Control* (step 2) addresses.

### Applying / reverting the GRUB change

```bash
sudo cp /etc/default/grub /etc/default/grub.bak
sudo sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT='quiet splash'/GRUB_CMDLINE_LINUX_DEFAULT='quiet splash processor.max_cstate=2 nvme_core.default_ps_max_latency_us=0 pcie_aspm=off'/" /etc/default/grub
sudo update-grub && sudo reboot

# verify after reboot
cat /proc/cmdline
cat /sys/module/nvme_core/parameters/default_ps_max_latency_us   # expect 0
ls /sys/devices/system/cpu/cpu0/cpuidle/                          # no state3 (C3)

# revert
sudo cp /etc/default/grub.bak /etc/default/grub && sudo update-grub
```

### Updating the BIOS without Windows (for reference)

Minisforum BIOS packages flash from the UEFI shell:

1. Format a USB stick as FAT32 and unzip the package to its root
   (`AfuEfix64.efi`, a `.nsh` script and the image).
2. Write down your BIOS settings, since the flash resets them.
3. Turn off Secure Boot, open the boot menu (F7) and choose
   *UEFI: Built-in EFI Shell*.
4. Run `fs0:`, then `ls`, then the `.nsh` script. Don't cut power while it flashes.
5. Load defaults, re-enable Secure Boot, restore your settings, then check with
   `cat /sys/class/dmi/id/bios_version`.

## Experiments and results

All runs, including the ones that went wrong, are documented in
[`experiments/`](experiments/). Each has its own README with the change made,
the conditions, the raw output and a verdict.

| # | Change | Valid? | Outcome |
|---|---|---|---|
| [00](experiments/00-baseline/) | stock | ✅ | Baseline |
| [01](experiments/01-timer-slack-artifact/) | stock | ⚠️ | Measurement bug found and fixed (timer slack hid C-state latency) |
| [02](experiments/02-kernel-params-vms-off/) | kernel params, **VMs stopped** | ❌ | Not comparable; showed package C-states give an idle box ~0.36 ms wake-ups |
| [03](experiments/03-kernel-params-steady-state/) | kernel params, VMs steady | ✅ | **No performance change** within noise |

**Kernel parameters, stock vs. applied (VMs in steady state):**

| Metric | Stock (range of 3 runs) | With params |
|---|---|---|
| CPU wake after 10 ms sleep, median | 10.0–10.8 µs | 11.4 µs |
| NVMe 4K read back-to-back, median / p99 | 47–50 µs / 2.1–3.4 ms | 47.7 µs / 2.1 ms |
| NVMe 4K read after 200 ms idle, median | 0.61–1.52 ms | 0.58 ms |
| memcpy, 1 thread | 37.6–37.9 GB/s | 37.1 GB/s |
| 7-Zip, 1 thread / all threads (MIPS) | 6,695–6,900 / 123,933–125,495 | 6,761 / 124,693 |

**Conclusion so far:** the mitigation costs no measurable performance (power
draw not measured). Whether it stops the freezes can only be judged after
about 4 weeks without one; see the incident log.

### Benchmark tool

`bench/run.sh <output-file>` builds and runs small tests that don't need root:

- `wakelat`: nanosleep overshoot with timer slack disabled (CPU C-state exit latency).
- `nvmelat`: QD1 4K random `O_DIRECT` reads, back-to-back and with 200 ms
  idle gaps (NVMe/PCIe wake latency).
- `membw`: single-thread memcpy bandwidth.
- 7-Zip: `7z b`, with 1 thread and with all threads.

Run it with the VMs in their normal steady state (after boot and JVM warm-up).
Background load adds noise, so compare against the baseline *range*.

## Repo layout

```
README.md            this file: problem, diagnosis, research, plan, summary
experiments/         one folder per test run: README (change, conditions, results, verdict) + raw output
bench/               benchmark sources and runner (bench/run.sh <output-file>)
scripts/diagnose.sh  post-crash log triage (boots, unclean shutdowns, errors, idle states, sysstat)
```

## If it freezes again

1. Power-cycle, then run `scripts/diagnose.sh` and add a dated entry to the log below.
2. Move to the next step in the action plan, and record it as a new experiment.

## Incident log

| Date | Kernel | Mitigations in place | Notes |
|---|---|---|---|
| 2026-08-28 | 7.0.0-30 | none | unclean shutdown in journal |
| 2026-08-31 | 7.0.0-30 | none | unclean shutdown in journal |
| 2026-09-25 | 7.0.0-30 | none | unclean shutdown in journal |
| 2026-10-12 07:30 | 7.0.0-38 | none | hard freeze at ~94% idle, nothing logged |
| 2026-10-12 09:40 | 7.0.0-38 | kernel params (step 1) | mitigation applied, monitoring starts. **No freeze since** (update this row) |
