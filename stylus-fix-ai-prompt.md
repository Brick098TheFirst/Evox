# TASK: Fork LineageOS 23 (gts7fewifi) → Evolution X + Fix S Pen / Touch Bugs

You are working on my behalf, connected to my GitHub account. I want you to do the following work and produce real code changes I can review and build. Be precise, verify every claim against the actual source, and do NOT guess — if a repo is missing or outdated, say so explicitly.

---

## 1. THE DEVICE

- **Device:** Samsung Galaxy Tab S7 FE (Wi‑Fi), model **T733**, codename **gts7fewifi**
- **SoC:** Qualcomm Snapdragon 778G (SM7325 / "yupik")
- **Input hardware (two SEPARATE digitizers — this is critical):**
  - **Capacitive finger touch:** Focaltech `focaltech,fts` (ft8203, firmware `tsp_focaltech/ft8203_gts7xllite.bin`) and/or Himax hx83121a (firmware `tsp_himax/hx83121a_gts7xllite.bin`). Sysfs: `/sys/class/sec/tsp`.
  - **S Pen:** Wacom EMR, driver `wacom,w90xx` on I2C addr `0x56`, firmware `epen/w9021_gts7xllite.bin`. Sysfs: `/sys/class/sec/sec_epen`.

## 2. THE CURRENT ROM

- LineageOS **23** (Android **16**), UNOFFICIAL, by Bushcat.
- XDA thread: https://xdaforums.com/t/rom-16-0-gts7fewifi-unofficial-lineageos-23-for-galaxy-tab-s7-fe-wifi-t733.4722361/
- It is a PORT of the **a52sxq** phone (the device tree is literally forked from `LineageOS/android_device_samsung_a52sxq`).
- The maintainer has flagged the kernel as unstable ("Kernel Panic and reboot under heavy network usage", "Display Rotation is WiP") and stopped publishing stable builds; newer test builds live in the Telegram group: **https://t.me/gts7x**

## 3. THE BUG I AM EXPERIENCING (write these symptoms down)

1. The S Pen draws fine **with no hand contact on the screen**.
2. The moment I rest my **palm** on the screen while drawing, the S Pen becomes **unresponsive** (input is dropped / ignored).
3. **Newer and more severe:** after I press the pen to the screen, **finger/palm touch stops working entirely** and does NOT recover — **only a full reboot restores touch**. After reboot, touch works again until I next press the pen, then it latches dead again.
4. This worked perfectly for ~1 week after flashing, then started "randomly." Nothing changed on my end (no OTA, no new case/magnet, no settings change).

### My root-cause hypothesis (verify, don't assume):
The Wacom driver uses `wacom,enable_sysinput_enabled` (see DTS below) to talk to Samsung's `sec_input` notifier framework. On stock, when the pen is in proximity, the touch driver is told to **suppress palm/finger touch**, and — crucially — when the pen leaves proximity, the suppression is **cleared**. On this port, that "clear" event is being dropped/latched, so:
- palm resting → pen suppressed (symptom 1), and
- pen contact → touch suppression latches ON forever until reboot (symptom 3).

The likely fix locations are (a) the kernel `sec_input_notifier.c` / wacom `w90xx` driver proximity-out handling, and (b) the userspace `.idc` file that mis-classifies the pen as a touchscreen.

---

## 4. SOURCE REPOSITORIES

### 4a. Repos the maintainer lists in the XDA thread (he adds "Trees below may be outdated!" — treat as authoritative starting points but VERIFY against actual branches):

- Kernel: https://github.com/LineageOS/android_kernel_samsung_sm7325
- Device (common): https://github.com/LineageOS/android_device_samsung_sm7325-common
- Device (gts7fewifi): https://github.com/LineageOS/android_device_samsung_gts7fewifi
- Vendor (common): https://github.com/Bush-cat/proprietary_vendor_samsung_sm7325-common
- Vendor (gts7fewifi): https://github.com/Bush-cat/proprietary_vendor_samsung_gts7fewifi

### 4b. Additional repos I found that are NOT listed above but are relevant (you MUST check these):

- **Bushcat's own device tree** (has commits NOT in LineageOS tree): https://github.com/Bush-cat/android_device_samsung_gts7fewifi — branch `lineage-23.2`
- **Bushcat's common tree**: https://github.com/Bush-cat/android_device_samsung_sm7325-common
- **Bushcat's kernel**: https://github.com/Bush-cat/android_kernel_samsung_sm7325 — only branch `lineage-22.1`
- **Bushcat's kernel "upstream"**: https://github.com/Bush-cat/android_kernel_samsung_sm7325_upstream — branches `lineage-22.2`, `dtsi-split`, `A736BXXUAFYE6`
- **Bushcat's device trees (separate DTS repo)**: https://github.com/Bush-cat/android_kernel_samsung_sm7325-devicetrees — branch `master`
- **TWRP tree** (for reference): https://github.com/Bush-cat/android_device_samsung_gts7fewifi-twrp
- **Official LineageOS Tab S7 (non-FE) reference** — same Wacom EMR hardware, use as a working reference: https://github.com/LineageOS/android_device_samsung_gts7lwifi and https://github.com/LineageOS/android_device_samsung_sm8250-common
- **Bushcat's frameworks_base fork** (probably NOT relevant — it's stale Android-10-era, appears to be for another device; verify): https://github.com/Bush-cat/android_frameworks_base

## 5. KEY FILES I HAVE ALREADY LOCATED (read these first, don't re-discover from scratch)

### 5a. Device tree — the pen `.idc` config (USERSpace, likely the palm-rejection quick fix):
`configs/idc/sec_e-pen.idc` (in `android_device_samsung_gts7fewifi`, branch `lineage-23.2`)

Contents:
```
touch.deviceType = touchScreen
touch.orientationAware = 1
```
This is copied to `vendor/usr/idc/sec_e-pen.idc` via `device.mk`.
**The commit that introduced `touch.deviceType = touchScreen`** is by TALU, titled:
"gts7fewifi: idc: Set S-Pen input device type to touchscreen — This gets rid of the pen pointer, while, perhaps surprisingly, retaining all pen-specific functionality."
URL: https://github.com/Bush-cat/android_device_samsung_gts7fewifi/commit/0811190f7216ed7de36b63a3023971f3ecf144e5

**Experiment to try:** change `touch.deviceType` to `stylus` (and consider adding/removing `touch.orientationAware`), rebuild, test palm + touch. This is the cheapest possible fix and directly affects how Android's InputReader classifies pen vs touch events (which drives palm rejection behavior).

Note: the official Tab S7 tree (`sm8250-common/configs/idc/sec_e-pen.idc`) uses the IDENTICAL `touch.deviceType = touchScreen` line — so this may not be the bug, but it is the correct place to experiment.

### 5b. Device tree — the Wacom/palm-rejection DTS node (the hardware contract):
`arch/arm64/boot/dts/samsung/gts7/gts7fewifi/yupik-sec-gts7fewifi-input-pen.dtsi`
(in repo `Bush-cat/android_kernel_samsung_sm7325-devicetrees`, branch `master`)

Key excerpt:
```dts
&qupv3_se13_i2c {
    status = "ok";
    wacom: wacom@56 {
        status = "okay";
        compatible = "wacom,w90xx";
        reg = <0x56>;
        pinctrl-0 = <&epen_int_active>;
        wacom_avdd-supply = <&pm8350c_l13>;
        wacom,regulator_boot_on;
        wacom,irq-gpio = <&tlmm 39 0>;
        wacom,fwe-gpio = <&tlmm 38 0>;
        wacom,boot_addr = <0x9>;
        wacom,origin = <0 0>;
        wacom,enable_sysinput_enabled;   /* <-- pen→touch suppression handshake */
        wacom,max_pressure = <4095>;
        wacom,max_tilt = <63 63>;
        wacom,max_height = <255>;
        wacom,invert = <1 0 1>;
        wacom,fw_path = "epen/w9021_gts7xllite.bin";
        wacom,module_ver = <2>;
        wacom,support_aop_mode = "1";
        wacom,table_swap = <2>;
        wacom,support_cover_noti;
        wacom,support_cover_detection;
    };
};
```

Other input DTS files in the same dir: `yupik-sec-gts7fewifi-input-ft820x.dtsi` (compatible `focaltech,fts`, `sec,firmware_name = "tsp_focaltech/ft8203_gts7xllite.bin"`), `yupik-sec-gts7fewifi-input-hx83121a.dtsi`.

### 5c. Common tree — touch permissions & sec_input wiring:
`init/init.samsung.rc` in `android_device_samsung_sm7325-common`:
- Touchscreen perms for `/sys/class/sec/tsp`, `/sys/class/sec/tsp1`, `/sys/class/sec/tsp2`
- **"Permission for Wacom"** block for `/sys/class/sec/sec_epen` (cmd, input/enabled, epen_firm_update, epen_reset, epen_reset_result, epen_checksum, epen_checksum_result, epen_saving_mode, epen_wcharging_mode, epen_ble_charging_mode, epen_fac_garage_mode, epen_fac_select_firmware, keyboard_mode, epen_disable_mode, aod_enable, aod_lcd_onoff_status, screen_off_memo_enable, dex_enable, hw_param)

### 5d. Kernel — Samsung input framework (where the suppression latch likely lives):
`drivers/input/sec_input/` (in `android_kernel_samsung_sm7325`):
- `sec_input_notifier.c` — the notifier framework that coordinates touch + pen ("sysinput")
- `sec_cmd.c`, `sec_common_fn.c`, `sec_input.h`, `sec_secure_touch.c`, `sec_tclm_v2.c`, `sec_virtual_tsp.c`, `sec_tsp_dumpkey.c`, `sec_tsp_log.c`

## 6. KNOWN PROBLEMS WITH THE PUBLIC SOURCES (critical — do not skip)

1. **The kernel that actually runs on my device is NOT fully published.**
   - `BoardConfig.mk` requires `TARGET_KERNEL_CONFIG := vendor/lineage-gts7fewifi_defconfig`
   - That defconfig does NOT exist in any public branch of `LineageOS/android_kernel_samsung_sm7325` (only `lineage-a52sxq_defconfig`, `lineage-a73xq_defconfig`, `lineage-m52xq_defconfig` exist), nor in Bushcat's kernel repos.
2. **The `wacom,w90xx` driver that the DTS references is NOT in any public kernel repo I could find** (not in `drivers/input/touchscreen/wacom_i2c.c`, no `w90xx` anywhere). Yet my pen draws, so the driver MUST exist somewhere (private branch, or a blob/module). **You must locate the real kernel source + the w90xx driver + the gts7fewifi defconfig before you can rebuild or fix anything.** Candidates to check: the Telegram group, `android_kernel_samsung_sm7325_upstream` branches, `android_kernel_samsung_sm7325-devicetrees`, and any `.repo` local_manifest/roomservice.xml I may provide.

## 7. WHAT I WANT YOU TO DO (in priority order)

### Priority 0 — Locate & pin the real kernel
- Find the kernel source that actually builds `lineage-gts7fewifi_defconfig` and contains the `wacom,w90xx` driver.
- Produce a `local_manifest.xml` / `roomservice.xml` that pins the CORRECT branches for: kernel, device (common + gts7fewifi), vendor (common + gts7fewifi).
- If the w90xx driver / defconfig genuinely isn't public, say so and tell me exactly what to ask the maintainer for in the Telegram group (draft the message).

### Priority 1 — Fork everything into my GitHub
- Fork all relevant repos (device tree, common, vendor x2, kernel) to my account.
- Use permissive-license-correct attributions (device trees are Apache-2.0, kernel is GPL-2.0 — keep headers intact).

### Priority 2 — Fix the S Pen / touch bug (the whole point)
Deliver concrete, reviewable changes, in this order:
1. **Try the `.idc` change first** — `touch.deviceType = stylus` in `sec_e-pen.idc` — and document expected vs observed behavior for palm rejection + the "touch latches dead" symptom.
2. **Diagnose the suppression latch in the kernel.** Trace `wacom,enable_sysinput_enabled` → `sec_input_notifier.c` → how the touch driver is told to suppress/release. Find where "proximity out" fails to clear the suppression. Propose a patch (e.g., ensure the notifier always fires a release on pen-out, add a watchdog, or log the state machine so we can see where it sticks).
3. **Diff against the official Tab S7** (`sm8250-common` + its kernel's sec_input/wacom handling) to spot what the sm7325 port is missing.
4. Add **debug logging** (dmesg/logcat) around pen proximity + touch-suppression so we can confirm the root cause on-device before finalizing.

### Priority 3 — Evolution X migration
- Confirm whether Evolution X for this device is already in progress (I saw commits in the device tree signed off by `AnierinB <anierin@evolution-x.org>`, an Evolution X maintainer — check for an `evolution-x` branch on the forks, and check the Telegram group).
- If not, produce the manifest + instructions to build Evolution X for gts7fewifi using these device/vendor trees, and note which EvoX repos must be swapped in (frameworks/base, Settings, SystemUI, vendor/aosp, prebuilts, etc.).

## 8. DELIVERABLES I EXPECT FROM YOU

1. A corrected `local_manifest.xml` pinning all correct branches.
2. Forked repos on my GitHub.
3. A diff for `sec_e-pen.idc` (the stylus experiment).
4. A root-cause writeup + patch for the touch-suppression latch (kernel), with the exact file(s) and a before/after explanation.
5. A plan (and manifest) for the Evolution X build.
6. If you hit the missing-kernel problem, a precise, polite message for me to post to the maintainer in the gts7x Telegram group, plus a list of exactly which files/branches to request.

## 9. HARD CONSTRAINTS

- Do NOT fabricate file contents or commit SHAs. Quote only what you can verify in the repos. If something is missing, report it, don't invent it.
- Do not re-derive what I've already found above — build on it. But DO verify it, because the XDA thread explicitly warns the trees may be outdated.
- Keep all license headers intact.
- This is a Wi-Fi-only T733 (gts7fewifi). Do NOT touch LTE/5G variants (they use a different CPU and will not work).
- I have the device unlocked with LineageOS recovery already; assume I can flash test builds easily.
