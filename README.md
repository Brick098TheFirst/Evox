# Evox — Evolution X for the Galaxy Tab S7 FE (gts7fewifi / SM-T733)

Fork of the LineageOS 23.2 gts7fewifi device tree, adapted for
**Evolution X (bka / Android 16)** and for fixing the S-Pen / palm /
touch bugs. Wi-Fi-only T733 — LTE/5G variants (T735/T736, different SoC)
are intentionally out of scope.

> **This is a tablet.** Landscape-native 2560×1600 @ 340dpi, EMR S-Pen,
> pogo keyboard cover, DeX, no RIL (`ro.radio.noril=yes`). All
> configuration preserves tablet semantics (`TARGET_IS_TABLET`,
> `PRODUCT_CHARACTERISTICS := tablet`, tablet Wi-Fi-only vendor config).

## Is this Evolution X now? — Yes, at device-tree level

Everything that lives in a *device tree* for an Evolution X build is in
this repo:

- **`evolution_gts7fewifi.mk`** + lunch target `evolution_gts7fewifi-userdebug`
  (registered in `AndroidProducts.mk` alongside the LineageOS target)
- Inherits **`vendor/lineage/config/common_full_tablet_wifionly.mk`** —
  Evolution X syncs its vendor tree (`vendor_evolution`) to `vendor/lineage`,
  so this is the correct EvoX inherit (verified against EvoX `bka` and
  current EvoX tablet devices like Lenovo tb351fu / Xiaomi pipa)
- EvoX bootanimation sizes itself from `TARGET_SCREEN_WIDTH/HEIGHT`
  (2560/1600, already set — no extra config needed)
- Plus the fixes: S-Pen `.idc` reclassification and the two kernel patches

The rest of Evolution X (frameworks/base, Settings, SystemUI,
`vendor/lineage`, etc.) comes from the **Evolution-X manifest** at sync
time — that's multi-gigabyte and can't live inside a device tree repo.
**No forks of anything are needed**: `scripts/setup-build.sh` clones all
of it straight from the upstream repos (EvoX + LineageOS + Bush-cat),
uses **this repo** as the device tree, and transfers the kernel patches
onto the kernel checkout automatically.

## One-command build

From a checkout of this repo, on a Linux box with ~150 GB free:

```bash
./scripts/setup-build.sh                 # Evolution X (bka, Android 16)
./scripts/setup-build.sh --rom lineage   # LineageOS 23.2 instead
```

What it does: install `repo` if missing → `repo init` (Evolution-X bka
or LineageOS lineage-23.2) → install the pinned local manifest
(`docs/local_manifests/gts7fewifi.xml`, which points `device/samsung/gts7fewifi`
at **this repo** and pins kernel/common/hardware/vendor so roomservice never
guesses) → `repo sync` → `git am` the S-Pen/touch kernel patches onto
`kernel/samsung/sm7325` → `lunch evolution_gts7fewifi-userdebug` → `m evolution`.

Useful flags: `--sync-only` (prepare, build later with `--build-only`),
`--patches-only` (re-apply kernel patches after a re-sync), `WORKDIR=`,
`VARIANT=`, `DEVICE_BRANCH=`, `JOBS=`. See `--help`.

Output: `out/target/product/gts7fewifi/*.zip`.

## The S-Pen / touch bug (why this fork exists)

The Wacom EMR driver asks the capacitive touch driver to stop scanning
while the pen is in range (`NOTIFIER_TSP_BLOCKING_REQUEST` /
`NOTIFIER_WACOM_PEN_HOVER_*` via Samsung's `sec_input` notifier), but the
FocalTech FT8203 driver never registered a listener — so the touch
controller keeps scanning, interferes with the EMR signal (pen drops when
your palm touches), and can wedge itself into a dead state on pen contact
(touch dies until reboot; no ESD recovery since `FTS_ESDCHECK_EN=0`).
The Tab S7's `sec_ts` driver implements exactly the missing handshake;
`patches/kernel/0001-*` ports that pattern to focaltech.

| Path | What |
|---|---|
| `docs/stylus-touch-bug-analysis.md` | **Start here** — verified root-cause writeup with file/line references + on-device test plan |
| `patches/kernel/` | The two kernel patches (auto-applied by the setup script) |
| `configs/idc/sec_e-pen.idc` | S-Pen reclassified `stylus` (was `touchScreen`) — userspace half of the fix |
| `docs/verified-source-map.md` | Which repo/branch actually builds this device (kernel mystery solved) |
| `docs/local_manifests/gts7fewifi.xml` | The one pinned manifest for both EvoX and LOS builds |
| `docs/evolution-x-build.md` | Migration status, build details, bring-up checklist |
| `docs/maintainer-telegram-message.md` | Draft message for the gts7x Telegram group |

## Credits / licenses

Device tree: LineageOS Project / Bushcat (Apache-2.0). Kernel patches:
GPL-2.0, applied to
[`Bush-cat/android_kernel_samsung_sm7325`](https://github.com/Bush-cat/android_kernel_samsung_sm7325)
(branch `lineage-22.1-gts7fewifi`). All original license headers retained.
