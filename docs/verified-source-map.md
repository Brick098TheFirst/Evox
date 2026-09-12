# Verified source map for gts7fewifi (checked 2026-09-12)

Everything below was checked against the live repos (`git ls-remote` /
GitHub API) during this session. "MISS" = repo does not exist (404).

## What the ROM actually consists of

| Component | Repo / branch | Status |
|---|---|---|
| Device tree (gts7fewifi) | `Bush-cat/android_device_samsung_gts7fewifi` @ `lineage-23.2` | OK — head `d9efcc0` = the base of this fork (`Brick098TheFirst/Evox`). **`LineageOS/android_device_samsung_gts7fewifi` does NOT exist.** |
| Device tree (common) | `LineageOS/android_device_samsung_sm7325-common` @ `lineage-23.2` | OK — pulled in automatically via `lineage.dependencies` (roomservice); requires `vendor/samsung/sm7325-common` blobs. Bushcat's own common repo only goes up to `lineage-23.0-temp-share`. |
| Kernel | `Bush-cat/android_kernel_samsung_sm7325` @ **`lineage-22.1-gts7fewifi`** | OK — the only public branch with `vendor/lineage-gts7fewifi_defconfig`, `drivers/input/wacom/` (w90xx), ft820x/himax drivers, gts7fewifi DTS. 19 commits ahead of `lineage-22.1`, first commit "Import gts7fewifi drivers from T733XXS8DXJ1". |
| Vendor blobs (device) | `Bush-cat/proprietary_vendor_samsung_gts7fewifi` @ `lineage-23.2-temp` | OK (branches: `lineage-22.1`, `lineage-23.0-temp-share`, `lineage-23.2-temp`; default is `lineage-22.1` — don't be fooled). Contains `proprietary/…/firmware/epen/w9021_gts7xllite.bin` etc. per `proprietary-files.txt`. |
| Vendor blobs (common) | `Bush-cat/proprietary_vendor_samsung_sm7325-common` @ `lineage-23.2` | OK — inherited by `sm7325-common/common.mk:379`. |
| DTS (maintained source) | `Bush-cat/android_kernel_samsung_sm7325-devicetrees` @ `master` | OK — dtsi-split source incl. `yupik-sec-gts7fewifi-input-pen.dtsi`. **Not wired into the ROM build** (the kernel branch's in-tree DTS is what compiles). |
| TWRP reference | `Bush-cat/android_device_samsung_gts7fewifi-twrp` @ `android-12.1` | OK (reference only). |

## Evolution X status

- **No `gts7fewifi`/`sm7325` repos exist in the `Evolution-X` org** (checked:
  `android_device_samsung_gts7fewifi`, `android_device_samsung_sm7325-common`,
  `android_kernel_samsung_sm7325` → all MISS). No Samsung device tree is
  published under the org at all.
- Evidence that an EvoX bring-up is in progress *outside* the org: the head
  commit of the device tree (`d9efcc0` "gts7fewifi: Set up default display
  orientation configs") is authored + signed-off by **AnierinB
  <anierin@evolution-x.org>** (Evolution X maintainer), and this fork
  (`Brick098TheFirst/Evox`) is based on exactly that commit.
- Evolution-X manifest branches today: `tiramisu` (A13), `udc` (A14),
  `vic` (A15), **`bka` (A16, `android-16.0.0_r4` + `lineage-23.2`)**,
  **`cnb` (A17, `android-17.0.0_r1` + `lineage-24.0`, current default)**.
  For this tree (LineageOS 23.2 base) the right target is **`bka`**.
- Build recipe for EvoX: see `docs/evolution-x-build.md`.

## Other repos mentioned in the original notes — status

| Repo | Finding |
|---|---|
| `Bush-cat/android_kernel_samsung_sm7325` @ `lineage-22.1` | exists, but **lacks** gts7fewifi defconfig/drivers — not the one the ROM uses |
| `Bush-cat/android_kernel_samsung_sm7325` @ `twrp-12.1` | TWRP kernel branch |
| `Bush-cat/android_kernel_samsung_sm7325_upstream` @ `lineage-22.2`, `dtsi-split`, `A736BXXUAFYE6` | exists — A73xq (SM-A736) stock-derived base + Bushcat's dtsi-split experiments; not used by the gts7fewifi ROM |
| `Bush-cat/android_device_samsung_sm7325-common` @ `lineage-22.*-gts7fewifi`, `lineage-23.0-temp-share` | exists — older/parallel branches; the LOS 23.2 build pairs with the **LineageOS** common tree |
| `Bush-cat/android_frameworks_base` | Android-10-era, not relevant (as suspected) |
| `LineageOS/android_device_samsung_gts7lwifi` + `sm8250-common` + `kernel_samsung_sm8250` @ `lineage-23.2` | exists — **working EMR-pen reference** (sec_ts driver implements TSP blocking); used as the architectural reference for the kernel fix |
| `averyvisentin/android_kernel_samsung_sm-t733` | stock OSS import, but **GKI-only** (no `drivers/` — the Samsung OSS drop for this model ships device drivers separately) |
| `ssch71/android_kernel_samsung_gts7fewifi_SM7325`, `qaz6750/android_kernel_samsung_gts7fewifi` @ `android16-5.4.y` | stock-derived mirrors; their focaltech drivers also have **no** TSP-blocking notifier handler |
| Samsung OSS portal (`opensource.samsung.com`) | down during analysis ("We're doing some work on site") — the definitive stock T733 kernel drop could not be pulled |

## No forks needed — the build is fully self-contained via this repo

`scripts/setup-build.sh` + `docs/local_manifests/gts7fewifi.xml` pull
everything directly from the upstream repos at build time:

- Evolution-X / LineageOS source (from the org manifests)
- device tree: **this repo** (`Brick098TheFirst/Evox` @ `arena/01a09644-evox`)
- kernel: Bush-cat @ `lineage-22.1-gts7fewifi`, with
  `patches/kernel/*.patch` auto-applied by the script (`git am`, or
  `git apply` fallback if no git identity is configured)
- common device tree + Samsung hardware repos: LineageOS @ `lineage-23.2`
- vendor blobs: Bush-cat's two vendor repos

Why the kernel/vendor sources aren't vendored *into* this repo: they're
multi-gigabyte git repositories that the `repo` tool must sync and track
(the full build tree is ~50-100 GB); a device tree repo only carries
makefiles/configs/patches. Transferring the files at build time via the
script achieves the same "everything in one place" effect while staying
in sync with upstream.

If you later want kernel changes upstreamed or standing builds, you can
fork `Bush-cat/android_kernel_samsung_sm7325`, push the patches to a
branch there, and point the manifest's `kernel/samsung/sm7325` entry at
it — but it is not required to build or test. All license headers are
preserved (Apache-2.0 device/vendor trees, GPL-2.0 kernel).
