# Evolution X for gts7fewifi — migration plan & build guide

## Status (verified 2026-09-12)

- **There is no official Evolution X support for this device.** The
  `Evolution-X` org has no `android_device_samsung_gts7fewifi`,
  `android_device_samsung_sm7325-common` or `android_kernel_samsung_sm7325`
  repos (all checked — 404), and in fact no Samsung device trees at all.
- An EvoX bring-up **is in progress outside the org**: the head of the
  LineageOS-lineage device tree (`d9efcc0`, "gts7fewifi: Set up default
  display orientation configs") is authored/signed-off by
  **AnierinB <anierin@evolution-x.org>**, an Evolution X maintainer —
  and this very fork (`Brick098TheFirst/Evox`) is based on that commit.
  Expect the eventual official tree to land as a fork under the
  maintainer's account first; coordinate in the gts7x Telegram group
  (see `docs/maintainer-telegram-message.md`) before duplicating work.
- Evolution X branch to target: **`bka` = Android 16**
  (`android-16.0.0_r4` + `lineage-23.2`) — same base as this device tree.
  (`cnb`, the current default, is Android 17 / `lineage-24.0` and would
  need the whole tree rebased onto LineageOS 24 first — not recommended
  until the LOS-23-based tree is stable.)

## What this fork already does for the migration

| Change | File |
|---|---|
| Evolution X product makefile (`evolution_gts7fewifi`), tablet Wi-Fi-only config, registered in lunch | `evolution_gts7fewifi.mk`, `AndroidProducts.mk` |
| Correct EvoX vendor inherit (`vendor/lineage/config/common_full_tablet_wifionly.mk` — EvoX syncs `vendor_evolution` to `vendor/lineage`) | `evolution_gts7fewifi.mk` |
| Pinned local manifest for the EvoX bka source tree | `docs/local_manifests/evolution-bka-gts7fewifi.xml` |
| S-Pen/touch fix (the reason this fork exists) | `patches/kernel/*.patch`, `configs/idc/sec_e-pen.idc`, `docs/stylus-touch-bug-analysis.md` |

Tablet-specific bits are preserved from the LineageOS tree
(`TARGET_IS_TABLET := true` in `device.mk`,
`PRODUCT_CHARACTERISTICS := tablet`, the tablet Wi-Fi-only vendor config,
2560×1600 boot animation, landscape-native orientation props) — this stays
a **tablet** build, not a scaled phone build.

## Building

```bash
# 1. Sync Evolution X (bka = Android 16)
mkdir evox && cd evox
repo init -u https://github.com/Evolution-X/manifest -b bka --git-lfs

# 2. Add the device pins
mkdir -p .repo/local_manifests
cp /path/to/Evox/docs/local_manifests/evolution-bka-gts7fewifi.xml \
   .repo/local_manifests/gts7fewifi.xml

# 3. (Optional but recommended) use your kernel fork with the S-Pen patches
#    applied instead of Bush-cat's branch:
#    edit the kernel/samsung/sm7325 <project> entry in the file above.

repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags

# 4. Build
. build/envsetup.sh
lunch evolution_gts7fewifi-bp4a-userdebug   # tab-completion also offers plain -userdebug
m evolution
```

Notes:

- The first `lunch` may pull `device/samsung/sm7325-common` +
  `hardware/samsung` etc. via roomservice (`lineage.dependencies`) — that's
  expected. If roomservice also adds its own `kernel/samsung/sm7325`
  entry, delete that duplicate from
  `.repo/local_manifests/roomservice.xml` and re-sync; the pinned
  `lineage-22.1-gts7fewifi` kernel is the one that must win (it's the only
  branch with `vendor/lineage-gts7fewifi_defconfig`).
- `TARGET_KERNEL_SOURCE`/`TARGET_KERNEL_CONFIG` come from
  `sm7325-common/BoardConfigCommon.mk` + our `BoardConfig.mk`; the kernel
  is built from source as part of the ROM.
- Signing/OTA: unofficial builds are signed with the test keys by default;
  set up your own release keys before distributing.

## Which EvoX repos replace LineageOS ones?

None manually — the EvoX manifest (`Evolution-X/manifest@bka`) already
provides EvoX's `frameworks/base`, `packages/apps/Settings`, SystemUI,
`vendor/lineage` (= `vendor_evolution`), GMS handling, etc. The only
additions needed are the device-specific repos in the local manifest
above. After the first successful build, diff the produced
`out/target/product/gts7fewifi/` props against the LineageOS build to
confirm EvoX features (evolution maintainer props, EvoX version in
`ro.evolution.*`, etc.) landed.

## Bring-up checklist

- [ ] First boot + adb/MTP
- [ ] Wi-Fi, Bluetooth, sensors
- [ ] Display rotation both ways (the maintainer flagged rotation as WiP on
      LineageOS 22 — the `ORIENTATION_*` props + `TARGET_RECOVERY_DEFAULT_ROTATION`
      in this tree are the current state of that work)
- [ ] Audio (speakers, quad-speaker balance), mics
- [ ] **S-Pen + touch with the kernel patches applied** (the actual goal)
- [ ] Battery/charging incl. 45W PD, keyboard cover via pogo, DeX
- [ ] Camera, screen-off memo (AOD pen features may need Samsung framework
      pieces that aren't in AOSP — verify what works)
- [ ] Encryption, SELinux enforcing (`getenforce`), no avc denials flood
- [ ] Kernel stability under network load (maintainer reported panics under
      heavy network usage on LOS 22 — watch for that; the qcacld-3.0 OOB fix
      in the gts7fewifi kernel branch's history may or may not cover it)
