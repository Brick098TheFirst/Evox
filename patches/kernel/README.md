# Kernel patches — S-Pen / touch suppression fix (gts7fewifi)

Patches are written against
[`Bush-cat/android_kernel_samsung_sm7325`](https://github.com/Bush-cat/android_kernel_samsung_sm7325),
branch **`lineage-22.1-gts7fewifi`** — the only public branch that contains
`arch/arm64/configs/vendor/lineage-gts7fewifi_defconfig` (which
`BoardConfig.mk` requires via `TARGET_KERNEL_CONFIG := vendor/lineage-gts7fewifi_defconfig`)
and the full gts7fewifi driver set (`drivers/input/wacom/`, focaltech ft820x,
himax hx831xx, pogo keyboard, battery, panel drivers). Both patches were
verified to `git apply --check` cleanly against that branch's HEAD.

| Patch | What it does |
|---|---|
| `0001-…focaltech…` | Makes the FT8203 touchscreen driver consume Samsung's `sec_input` pen notifications: TSP scan is paused (`FTS_REG_POWER_MODE = SCAN_OFF`) while the S-Pen is in range and resumed when it leaves. This is the kernel-side fix for the palm/touch bugs. |
| `0002-…wacom…` | Debug only: logs the result of the wacom driver's `NOTIFIER_TSP_BLOCKING_REQUEST/RELEASE` notifications in dmesg so you can see whether anyone consumed them. |

## Applying

The build setup script applies these automatically after `repo sync`:

```bash
./scripts/setup-build.sh              # full build, patches included
./scripts/setup-build.sh --patches-only   # just (re-)apply the patches
```

By hand:

```bash
git clone https://github.com/Bush-cat/android_kernel_samsung_sm7325 -b lineage-22.1-gts7fewifi
cd android_kernel_samsung_sm7325
git am /path/to/Evox/patches/kernel/0001-*.patch /path/to/Evox/patches/kernel/0002-*.patch
# or, without commit metadata:
# git apply 0001-*.patch 0002-*.patch
```

Then build the kernel as part of the ROM (the device tree builds it from
source; no prebuilt kernel is used) — see `docs/local_manifests/gts7fewifi.xml`
to pin the kernel repo/branch in your build tree.

## On-device verification (after flashing)

Watch the handshake in dmesg / logcat while hovering, drawing, and resting
your palm:

```bash
adb shell su -c 'dmesg -w' | grep -Ei 'sec_e-pen|fts|wacom|TSP BLOCK'
```

What you should see with both patches applied:

```
sec_e-pen …: [HI] x:… y:…                 <- pen enters range (wacom)
… [FTS_TS/I]fts_sec_touch_notify_call: S-Pen hover in
… [FTS_TS/I]fts_sec_touch_notify_call: S-Pen in range: TSP scan blocked   <- only if the IC sends a TSP_STOP packet
… [FTS_TS/I]fts_sec_touch_notify_call: S-Pen hover out
sec_e-pen …: [HO] …                       <- pen leaves range
```

Without patch 0001 (e.g. on the current build), you will instead see the
wacom driver log `TSP BLOCK REQUEST notified (ret=0)` (ret=0 is
`NOTIFY_DONE` — nobody consumed it) — that is the smoking gun the root-cause
writeup is based on: `docs/stylus-touch-bug-analysis.md`.
