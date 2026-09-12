# Evox — Evolution X for the Galaxy Tab S7 FE (gts7fewifi / SM-T733)

Fork of the LineageOS 23.2 gts7fewifi device tree, being adapted for
**Evolution X (bka / Android 16)** and for fixing the S-Pen / palm /
touch bugs. Wi-Fi-only T733 — LTE/5G variants (T735/T736, different SoC)
are intentionally out of scope.

> **This is a tablet.** Landscape-native 2560×1600 @ 340dpi, EMR S-Pen,
> pogo keyboard cover, DeX, no RIL (`ro.radio.noril=yes`). All
> configuration below preserves tablet semantics
> (`TARGET_IS_TABLET`, `PRODUCT_CHARACTERISTICS := tablet`,
> tablet Wi-Fi-only vendor config).

## What's in here

| Path | What |
|---|---|
| `evolution_gts7fewifi.mk` (+ `AndroidProducts.mk`) | Evolution X product, lunch target `evolution_gts7fewifi-userdebug` |
| `configs/idc/sec_e-pen.idc` | S-Pen reclassified `stylus` (was `touchScreen`) — userspace half of the pen/touch fix, see analysis |
| `patches/kernel/` | Two kernel patches for `Bush-cat/android_kernel_samsung_sm7325@lineage-22.1-gts7fewifi`: focaltech ft820x implements Samsung's `sec_input` TSP-blocking handshake; wacom logs the notification results |
| `docs/stylus-touch-bug-analysis.md` | **Start here** — verified root-cause writeup of the pen/palm/touch bug, with file/line references and a test plan |
| `docs/verified-source-map.md` | Which repo/branch actually builds this device (kernel mystery solved), what exists, what's missing, fork list |
| `docs/local_manifests/lineage-23.2-gts7fewifi.xml` | Pinned manifest for a LineageOS 23.2 build |
| `docs/local_manifests/evolution-bka-gts7fewifi.xml` | Pinned manifest for the Evolution X (bka) build |
| `docs/evolution-x-build.md` | Migration status + step-by-step EvoX build instructions + bring-up checklist |
| `docs/maintainer-telegram-message.md` | Draft message for the gts7x Telegram group (pen bug, kernel status, EvoX coordination) |

## TL;DR of the bug (details in the docs)

The Wacom EMR driver asks the capacitive touch driver to stop scanning
while the pen is in range (`NOTIFIER_TSP_BLOCKING_REQUEST` /
`NOTIFIER_WACOM_PEN_HOVER_*` via Samsung's `sec_input` notifier), but the
FocalTech FT8203 driver never registered a listener — so the touch
controller keeps scanning, interferes with the EMR signal (pen drops when
your palm touches), and can wedge itself into a dead state on pen contact
(touch dies until reboot, no ESD recovery since `FTS_ESDCHECK_EN=0`).
The Tab S7's `sec_ts` driver implements exactly the missing handshake;
`patches/kernel/0001-*` ports that pattern to focaltech using the
driver's own `fts_set_scan_off()` primitive.

## Quick build (Evolution X)

```bash
repo init -u https://github.com/Evolution-X/manifest -b bka --git-lfs
# add docs/local_manifests/evolution-bka-gts7fewifi.xml → .repo/local_manifests/
repo sync -c -j$(nproc --all)
. build/envsetup.sh && lunch evolution_gts7fewifi-bp4a-userdebug
m evolution
```

For LineageOS 23.2 instead, use
`docs/local_manifests/lineage-23.2-gts7fewifi.xml` and
`lunch lineage_gts7fewifi-userdebug`.

## Credits / licenses

Device tree: LineageOS Project / Bushcat (Apache-2.0). Kernel patches:
GPL-2.0, to be applied to
[`Bush-cat/android_kernel_samsung_sm7325`](https://github.com/Bush-cat/android_kernel_samsung_sm7325)
(branch `lineage-22.1-gts7fewifi`). All original license headers retained.
