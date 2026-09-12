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
| One pinned local manifest that works for both EvoX bka and LOS 23.2 (device tree = this repo) | `docs/local_manifests/gts7fewifi.xml` |
| One-shot setup script (clone everything, apply kernel patches, build) | `scripts/setup-build.sh` |
| S-Pen/touch fix (the reason this fork exists) | `patches/kernel/*.patch`, `configs/idc/sec_e-pen.idc`, `docs/stylus-touch-bug-analysis.md` |

Tablet-specific bits are preserved from the LineageOS tree
(`TARGET_IS_TABLET := true` in `device.mk`,
`PRODUCT_CHARACTERISTICS := tablet`, the tablet Wi-Fi-only vendor config,
2560×1600 boot animation, landscape-native orientation props) — this stays
a **tablet** build, not a scaled phone build.

### Device-facing options in `evolution_gts7fewifi.mk` (all verified against vendor_evolution @ bka)

| Option | Value | Why |
|---|---|---|
| `WITH_GMS` | `true` | **GApps baked into the ROM** (`vendor/gms` via `common_full_tablet_wifionly.mk`; set `false` for a vanilla build — version gets a `-Vanilla` suffix) |
| `EVO_BUILD_TYPE` | `Unofficial` | must be `Official`/`Unofficial`, else the vendor errors out |
| `EVO_MAINTAINER` | `Jayden` | consumed by vendor variants that read it; the visible "Maintained by Jayden" comes from the `SettingsResDevice` overlay (`build_maintainer_summary` — EvoX Settings falls back to that string when the device isn't in the OTA DB) |
| `TARGET_SUPPORTS_64_BIT_APPS` | `true` | EvoX's gate for Face Unlock — the T733 has no fingerprint sensor, so this is the only biometric unlock |
| `TARGET_ENABLE_FP_OVERRIDE` | `true` (default) | Pixel fingerprint spoof for Wallet/RCS; set `false` and re-add the Samsung `PRODUCT_BUILD_PROP_OVERRIDES` for stock identity |
| `TARGET_SCREEN_WIDTH/HEIGHT` | 2560/1600 | drives EvoX's generated bootanimation |

EvoX-wide features (Evolver in Settings, blur, Quick Tap, GameSpace,
Aperture camera, OTA updater) come from the vendor config automatically —
no device action needed.

## Building

**Easy way (no forks needed, from a checkout of this repo):**

```bash
./scripts/setup-build.sh    # EvoX bka; add --sync-only to skip the build
```

The script clones everything from upstream (Evolution-X manifest bka +
this repo as device tree + pinned kernel/common/hardware/vendor), applies
`patches/kernel/*.patch` to the kernel via `git am` (idempotent; falls
back to `git apply`), and builds `evolution_gts7fewifi-userdebug`.

**Manual way (same thing by hand):**

```bash
repo init -u https://github.com/Evolution-X/manifest -b bka --git-lfs
mkdir -p .repo/local_manifests
cp /path/to/Evox/docs/local_manifests/gts7fewifi.xml .repo/local_manifests/
repo sync -c -j$(nproc)
(cd kernel/samsung/sm7325 && git am /path/to/Evox/patches/kernel/*.patch)
. build/envsetup.sh
lunch evolution_gts7fewifi-userdebug
m evolution
```

Notes:

- The local manifest pins **every** device-side repo (device tree = this
  fork, common tree, kernel, hardware/samsung, hardware/samsung_slsi/nfc,
  both vendor blob repos), so roomservice has nothing left to fetch and
  can never pull the wrong kernel branch. `lineage-22.1-gts7fewifi` is the
  only branch with `vendor/lineage-gts7fewifi_defconfig`.
- `TARGET_KERNEL_SOURCE`/`TARGET_KERNEL_CONFIG` come from
  `sm7325-common/BoardConfigCommon.mk` + our `BoardConfig.mk`; the kernel
  is built from source as part of the ROM.
- If you merge this work into another branch of your fork, set
  `DEVICE_BRANCH=<branch>` for the script (or edit the manifest's
  `device/samsung/gts7fewifi` revision).
- After a later `repo sync`, re-apply the kernel patches if the sync
  rebased them away: `./scripts/setup-build.sh --patches-only`.
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

## Building on a low-RAM PC (16 GB) — e.g. i7-4790S / 16 GB / 900 GB disk

The official LineageOS guidance recommends 64 GB RAM for Android 16-era
builds; 16 GB is **below spec** but workable with preparation. The
setup script auto-detects low RAM and caps parallel jobs (8 threads →
`-j6`); this section covers the rest.

### One-time preparation

```bash
# 1. Build packages (per LineageOS 23.2 wiki, Ubuntu 22.04/24.04)
sudo apt update
sudo apt install bc bison build-essential ccache curl erofs-utils flex \
    g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick \
    protobuf-compiler python3-protobuf python-is-python3 \
    lib32readline-dev lib32z1-dev libdw-dev libelf-dev libgnutls28-dev \
    lz4 libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush \
    rsync schedtool squashfs-tools xsltproc xxd zip zlib1g-dev

# 2. Git identity (repo init refuses to run without it)
git config --global user.name "Jayden"
git config --global user.email "you@example.com"
git config --global trailer.changeid.key "Change-Id"
git lfs install

# 3. Swap — the difference between a slow build and a crashed one.
#    zram (compressed RAM swap, ~8 GB effective):
sudo apt install zram-tools
echo -e "ALGO=zstd
PERCENT=50" | sudo tee /etc/default/zramswap
sudo systemctl restart zramswap
#    Plus a 32 GB disk swapfile as overflow (on the fast disk!):
sudo fallocate -l 32G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 4. ccache — first build unaffected, rebuilds drop dramatically
echo 'export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache' >> ~/.bashrc
source ~/.bashrc && ccache -M 50G
```

### Running it

```bash
git clone https://github.com/Brick098TheFirst/Evox -b arena/01a09644-evox
cd Evox
./scripts/setup-build.sh        # auto: -j6 on 16 GB RAM
# or explicitly: JOBS=6 ./scripts/setup-build.sh
```

Run it inside `tmux` (`sudo apt install tmux`) so a logout doesn't kill
a 15-hour build: `tmux new -s build`, run, detach with Ctrl-B D,
re-attach with `tmux attach -t build`.

### What to expect (i7-4790S, 4C/8T)

| Stage | Rough time |
|---|---|
| `repo sync` (~100–150 GB) | 1–3 h (network-bound) |
| First full build (`m evolution`) | **12–24 h** — plan overnight, possibly into the next day |
| Incremental rebuild (with ccache warm) | ~1–2 h |
| Kernel-only change + rebuild | ~30–60 min |

Tips:
- Build on an SSD if at all possible; on an HDD expect the long end
  (or worse).
- Close browsers/IDEs/etc. — every GB counts.
- If a job gets OOM-killed (`ninja: job exited with signal 9` /
  `cc1plus killed`), drop to `JOBS=4` and retry with
  `./scripts/setup-build.sh --build-only` (the tree is already synced;
  it resumes where it stopped).
- The 4790S is a 65 W part — a 15-hour all-core load is fine thermally,
  just make sure dust filters/heatsink are clear.
- Disk usage lands around 150–250 GB total (source + output + ccache);
  900 GB free is comfortable.
