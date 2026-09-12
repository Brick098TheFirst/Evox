# S-Pen / palm / touch bug on gts7fewifi — verified root-cause analysis

**Device:** Samsung Galaxy Tab S7 FE Wi-Fi (SM-T733, `gts7fewifi`), Snapdragon 778G (SM7325)
**ROM under test:** LineageOS 23.2 (Android 16, unofficial by Bushcat); same trees are the base for the Evolution X port in this repo.
**Kernel under test:** `Bush-cat/android_kernel_samsung_sm7325` @ `lineage-22.1-gts7fewifi` (the branch actually used by the ROM — see "Kernel provenance" below; every code reference below was read directly from that branch).

---

## 1. Symptoms (from the bug report)

1. S-Pen draws fine **as long as no hand contact** is on the screen.
2. Resting a **palm** on the screen while drawing makes the pen **unresponsive** (input dropped).
3. (New, more severe) after pressing the pen to the screen, **finger/palm touch stops working entirely** and only a full reboot recovers it.
4. Worked fine for ~1 week after flashing, then started "randomly". No OTA, case, magnet or settings change in between.

## 2. Hardware / driver topology (verified from DTS + kernel)

The device has **two independent digitizers**:

| Digitizer | IC / driver | Input device | Firmware |
|---|---|---|---|
| Capacitive finger touch (TDDI — touch is integrated into the display driver IC) | FocalTech **FT8203** (on this unit; some hw revisions use Himax HX83121A) — `drivers/input/touchscreen/focaltech/ft820x/` (`focaltech_ts_ft820x.ko`) | `sec_touchscreen` (+ `sec_touchpad` for DeX) | `tsp_focaltech/ft8203_gts7xllite.bin` |
| S-Pen (Wacom EMR, digitizer under the LCD) | Wacom W9021 — `drivers/input/wacom/` (`wez01.ko`, Kconfig `EPEN_WACOM_WEZ01`) | `sec_e-pen` | `epen/w9021_gts7xllite.bin` |

DTS sources (in `Bush-cat/android_kernel_samsung_sm7325-devicetrees@master`, `arch/arm64/boot/dts/samsung/gts7/gts7fewifi/`):

- `yupik-sec-gts7fewifi-input-pen.dtsi` — `compatible = "wacom,w90xx"`, I2C 0x56, `wacom,enable_sysinput_enabled`, `wacom,fw_path = "epen/w9021_gts7xllite.bin"`.
- `yupik-sec-gts7fewifi-input-ft820x.dtsi` — `compatible = "focaltech,fts"`, `enable_sysinput_enabled`, `sec,firmware_name = "tsp_focaltech/ft8203_gts7xllite.bin"`, `support_dex`.

Both `modules.load` (device tree) and the defconfig confirm what actually loads:
`wez01.ko` (wacom), `focaltech_ts_ft820x.ko` (touch), `stm32_pogo.ko` (Book Cover Keyboard), `sec_cmd.ko`, `sec_common_fn.ko`, `sec_tsp_log.ko`, … Himax is **not** built for this configuration, and `CONFIG_INPUT_SEC_NOTIFIER=y` (built-in).

## 3. How Samsung's pen↔touch coordination is *supposed* to work

Samsung kernels coordinate the EMR pen and the capacitive TSP through the
`sec_input` blocking-notifier chain (`drivers/input/sec_input/sec_input_notifier.c`,
events defined in `sec_input.h`):

- The wacom driver (`drivers/input/wacom/wacom_i2c.c`) fires:
  - `NOTIFIER_WACOM_PEN_HOVER_IN` / `NOTIFIER_WACOM_PEN_HOVER_OUT` on pen proximity transitions (coordinate handler, `wacom_i2c_coord()`),
  - `NOTIFIER_TSP_BLOCKING_REQUEST` / `NOTIFIER_TSP_BLOCKING_RELEASE` whenever the Wacom IC sends a **TSP_STOP packet** (`wac_i2c_block_tsp_scan()`, ~line 1000) — i.e. the IC itself asks "make the touch controller stop scanning, it's interfering with me".
- A TSP driver that *consumes* those events pauses scanning for the duration of pen proximity.

Reference implementations that **do** consume them:

- **Tab S7 / S7+ (sm8250, official LineageOS, same EMR pen hardware):**
  `drivers/input/touchscreen/sec_ts/y79a_c/sec_ts.c` → `sec_touch_notify_call()`:
  `NOTIFIER_TSP_BLOCKING_REQUEST` → `sec_ts_set_scan_mode(ts, ENABLE_TSP_SCAN_BLOCK)`, `RELEASE` → `DISABLE_TSP_SCAN_BLOCK`, plus pen insert/remove/charging modes.
- **STM (pogo keyboard touchpad):** `drivers/input/sec_input/stm/stm_core.c` → `stm_touch_notify_call()` writes `STM_TS_CMD_FUNCTION_SET_TSP_BLOCK` on REQUEST/RELEASE and handles hover/pen-insert events.
- The display driver handles `NOTIFIER_TSP_ESD_INTERRUPT` and LFD lock events (`techpack/display/msm/samsung/ss_dsi_panel_common.c`).

## 4. What is actually broken on gts7fewifi (verified)

**The FT8203 touchscreen driver has zero `sec_input` integration.** In
`drivers/input/touchscreen/focaltech/ft820x/` there is no
`sec_input_register_notify()` call, no handler for
`NOTIFIER_TSP_BLOCKING_*` or `NOTIFIER_WACOM_PEN_HOVER_*`. (It includes
`sec_input.h` indirectly through `focaltech_common.h` — for the
`input_info()` logging macros — but never registers a notifier.)

A tree-wide search of the kernel shows the **only** consumer of
`NOTIFIER_TSP_BLOCKING_REQUEST/RELEASE` is `stm_core.c` — the **pogo
keyboard touchpad** — which is not the main touchscreen.

Consequently, when the pen comes into range and the Wacom IC sends
TSP_STOP packets:

- the wacom driver logs the request and calls `sec_input_notify(...)` —
  and nothing blocks the FT8203's scanning;
- the FT8203 keeps scanning at full rate while the EMR digitizer excites
  the panel.

This maps 1:1 onto the symptoms:

| Symptom | Mechanism |
|---|---|
| Palm contact kills the pen (symptom 2) | The FT8203 actively scans the large palm contact; its drive pulses interfere with the EMR signal, so the Wacom IC degrades/drops pen events. This is exactly why the Wacom IC *asks* for TSP scan-stop via TSP_STOP packets — the request goes nowhere. |
| Pen press kills touch until reboot (symptom 3) | With the TSP never quiesced, the pen's EMR field (strongest on contact) drives the FT8203 into a noise/error state from which its firmware does not recover on its own. The driver has **no recovery path**: `FTS_ESDCHECK_EN = 0` and `FTS_POINT_REPORT_CHECK_EN` is not enabled (`focaltech_config.h`), so nothing detects or resets a wedged controller. Only the probe-time init (i.e. reboot) brings it back. |
| Fine for a week, then "random" (symptom 4) | The condition is load/environment-dependent (humidity, palm pressure, pen tilt change the interference coupling), so it appears intermittent. Nothing in /data "latches" it; the same interference was always there, the trigger threshold just varies. |

Two aggravating userspace factors (TALU's change in this device tree):

`configs/idc/sec_e-pen.idc` classified the pen as
`touch.deviceType = touchScreen`, i.e. the pen is a **second internal
touchscreen** next to `sec_touchscreen`. On Android 16 that means pen
strokes run through the ML palm-rejection pipeline that is meant for
finger streams, and cross-device stylus/finger arbitration in the
InputReader does not engage the way it does for a properly classified
stylus device. This change is being reverted/tested as `stylus` in this
branch (see §6).

## 5. Why stock OneUI doesn't show this (best available evidence)

- The exact same touch firmware blobs are shipped in the vendor
  (`ft8203_gts7xllite.bin`, pulled from stock), and the driver code in
  the LineageOS kernel was imported from the stock kernel drop
  (kernel branch first commit: *"WiP sm7325: Import gts7fewifi drivers
  from T733XXS8DXJ1"*).
- Stock-derived mirrors I could check
  (`ssch71/android_kernel_samsung_gts7fewifi_SM7325`,
  `qaz6750/android_kernel_samsung_gts7fewifi@android16-5.4.y`) **also**
  have no TSP-blocking handler in their focaltech driver — the only
  `sec_input_notify` consumers there are the same wacom/stm/display
  files.
- Samsung's own OSS portal (which would settle this definitively with
  the stock T733 drop) was unreachable during this analysis
  ("We're doing some work on site").

So on stock, coexistence is most plausibly handled by Samsung's
framework/tuner stack and/or timing details that the AOSP input stack
doesn't replicate — **or** the stock kernel drop for T733 does contain
additional glue we could not inspect. Either way: *on the LineageOS/EvoX
build the coordination demonstrably does not happen*, and the notifier
handshake that Samsung's own Tab S7 driver implements is the correct,
architecture-consistent place to restore it. Confirming with the
maintainer / stock drop is listed as an open question in
`docs/maintainer-telegram-message.md`.

## 6. The fix, in order of cost

### 6.1 Userspace experiment (this repo, already applied here)

`configs/idc/sec_e-pen.idc`: `touch.deviceType = stylus` (was `touchScreen`).

- **Expected:** pen keeps all function, palm rejection improves in apps
  that key off stylus streams, pen strokes no longer go through the
  touchscreen palm-rejector. A hover pointer/circle reappears (cosmetic
  regression that the original `touchScreen` hack was hiding).
- **This alone will likely NOT fix symptom 3** (touch latching dead) if
  that is the FT8203 wedging from EMR interference — that is kernel-side.

### 6.2 Kernel fix (patches/kernel/, applies to `lineage-22.1-gts7fewifi`)

`0001`: focaltech ft820x registers a `sec_input` notifier and tracks
two blocking sources independently; touch scanning is paused while
either is active, using `fts_set_scan_off()` (writes
`FTS_REG_POWER_MODE = 0x04 SCAN_OFF` — the driver's existing,
cover-mode-proven primitive; touch scan paused, display unaffected
since this is a TDDI):

- **(a) TSP_STOP handshake** (the stock Samsung mechanism):
  `NOTIFIER_TSP_BLOCKING_REQUEST` → block, `RELEASE` → unblock;
- **(b) hover gating** (safety net): `NOTIFIER_WACOM_PEN_HOVER_IN`
  blocks, `HOVER_OUT` unblocks — so even if the Wacom IC on a given
  unit never emits TSP_STOP packets, scanning is still paused while
  the pen is in proximity. Toggleable at runtime via
  `/sys/module/focaltech_ts_ft820x/parameters/pen_hover_gating`
  (default on; or `focaltech_ts_ft820x.pen_hover_gating=0` on the
  cmdline). The TSP_STOP path is always on;
- block requests are ignored while suspended or during firmware
  upgrade, and resume force-releases any still-held block so scan can
  never stay off across suspend/resume;
- the handler is defined before `fts_ts_probe_entry()` (declaration
  order matters — the first version of this patch had it after probe
  and would not have compiled);
- everything is guarded by `#if IS_ENABLED(CONFIG_INPUT_SEC_NOTIFIER)`
  like the rest of the tree.

`0002`: wacom logs the `sec_input_notify()` return values in
`wac_i2c_block_tsp_scan()` — before the fix you can *see*
`ret=0` (`NOTIFY_DONE` = nobody handled it), after the fix you see the
focaltech handler's own logs.

**Verification status of the patches** (what was and wasn't tested):

- ✅ `git apply --check` clean against
  `lineage-22.1-gts7fewifi` HEAD (`d23fb02`);
- ✅ the added handler code was extracted verbatim and compiled with
  gcc `-Wall -Wextra -Werror` in a stub harness, and the full state
  machine was executed across 6 scenarios — hover+TSP_STOP overlap,
  hover-only, runtime gating toggle, duplicate events, suspended/
  fw-upgrade guards, and resume force-release — all behaving correctly;
- ✅ declaration order (handler before first use in probe) verified in
  the patched source;
- ❌ NOT compiled inside the actual kernel tree (needs the full
  aarch64 Android build environment) — first real `m evolution` run
  will confirm;
- ❌ NOT tested on hardware — that's the on-device test plan below.

### 6.3 If the Wacom IC never sends TSP_STOP packets on this unit

Already covered: hover gating (source b above) pauses scanning on pen
proximity regardless of TSP_STOP packets. If you prefer the pen NOT to
suppress touch while merely hovering (stock-like behaviour), disable it:

```bash
adb shell su -c 'echo N > /sys/module/focaltech_ts_ft820x/parameters/pen_hover_gating'
```

### 6.4 Optional hardening (not in the patches yet)

- Enable `FTS_ESDCHECK_EN` (needs `focaltech_esdcheck.c` bring-up and
  testing) or add a lightweight watchdog: if no TSP interrupt for N
  seconds while `!suspended` and screen on, reset the IC. This directly
  targets "touch dead until reboot" regardless of root cause.

## 7. Test plan (on-device)

1. Flash build with `.idc` change only → retest symptoms 2 and 3.
2. `adb shell su -c 'dmesg -w' | grep -Ei 'sec_e-pen|fts|TSP BLOCK'`:
   - Reproduce symptom 2 (palm + draw): look for `[FTS_TS/I]…S-Pen hover in`
     and whether `TSP BLOCK REQUEST` appears (wacom IC asking for scan stop).
   - Reproduce symptom 3 (pen press): watch for focaltech error logs,
     i2c errors, or silence after the press (silence = wedged controller).
3. Flash kernel with both patches → same tests. With the handshake
   active, palm-while-drawing should no longer degrade the pen, and
   touch should survive pen contact.
4. Long-tail: multi-hour note-taking session, cover open/close, DeX
   on/off, screen-off memo if used.

## 8. Key source references (branch `lineage-22.1-gts7fewifi`)

- `drivers/input/wacom/wacom_i2c.c`
  - `~line 1000` `wac_i2c_block_tsp_scan()` — TSP_STOP packet handling, `is_tsp_block` state, `tsp_block_cnt`
  - `~line 1309/1416` hover in/out notifications in the coordinate handler
  - `~line 3022` `input->name = "sec_e-pen"`; `~line 3077` `sec_input_register_notify(&wac_i2c->nb, wacom_notifier_call, 2)`
  - `~line 2873` `pdata->enable_sysinput_enabled = of_property_read_bool(np, "wacom,enable_sysinput_enabled")`
- `drivers/input/sec_input/sec_input_notifier.c` — blocking notifier chain; `sec_input.h` `~line 486` event enum, `~line 514` `enum notify_set_scan_mode`
- `drivers/input/touchscreen/focaltech/ft820x/`
  - `focaltech_config.h`: `FTS_PEN_EN 0`, `FTS_ESDCHECK_EN 0`, `FTS_GESTURE_EN 0`, `FTS_MT_PROTOCOL_B_EN 1`
  - `focaltech_reg.h`: `FTS_REG_POWER_MODE 0xA5`, `…_SLEEP 0x03`, `…_SCAN_OFF 0x04`
  - `focaltech_sec_cmd.c` `~line 1952` `fts_set_scan_off()` (exported; used by cover mode)
  - `focaltech_core.c` `~line 1060` `sec_touchscreen` input device; suspend path `~line 2139` writes SLEEP + holds reset low
- `drivers/input/sec_input/stm/stm_core.c` `~line 1461` `stm_touch_notify_call()` — reference TSP-block consumer
- `LineageOS/android_kernel_samsung_sm8250@lineage-23.2` `drivers/input/touchscreen/sec_ts/y79a_c/sec_ts.c` `~line 244` `sec_touch_notify_call()` — Tab S7 reference consumer
- DTS: `Bush-cat/android_kernel_samsung_sm7325-devicetrees@master`, `arch/arm64/boot/dts/samsung/gts7/gts7fewifi/yupik-sec-gts7fewifi-input-{pen,ft820x,hx83121a}.dtsi`

## 9. Kernel provenance (Priority 0 of the original task — resolved)

Contrary to the original task notes ("kernel not published"), the kernel
**is** public. Verified facts:

- `BoardConfig.mk` requires `vendor/lineage-gts7fewifi_defconfig`.
- That defconfig exists **only** in
  `Bush-cat/android_kernel_samsung_sm7325` branch **`lineage-22.1-gts7fewifi`**
  (LineageOS's own `lineage-23.2` kernel branch only has a52sxq/a73xq/m52xq
  defconfigs).
- The same branch carries `drivers/input/wacom/` (the `wacom,w90xx`
  driver the DTS references), the ft820x/himax touch drivers, the pogo
  keyboard stack, battery/charger, panel drivers, and the gts7fewifi DTS
  (DTBO overlay fragments against `vendor/qcom/yupik.dtb`, added by
  "Import gts7fewifi drivers from T733XXS8DXJ1").
- The LOS 22.1 XDA thread for this device links exactly this branch as
  the kernel source; the LOS 23 build reuses it (nothing newer is
  public).
- `Bush-cat/android_kernel_samsung_sm7325-devicetrees@master` is the
  maintained dtsi-split DTS source (the kernel branch contains the
  equivalent expanded overlay form). DTS edits for your own builds can
  go to either, but note the ROM build compiles the kernel branch's
  in-tree copies — the devicetrees repo is not wired into the build.
