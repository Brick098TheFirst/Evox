# Draft message for the maintainer (Telegram: https://t.me/gts7x)

Context: the original task expected the kernel to be unpublished — that
turned out to be wrong (it lives on the `lineage-22.1-gts7fewifi` branch),
so the message below focuses on what's genuinely unanswerable from public
sources: the pen/touch bug, the kernel-panic report, and whether the
Evolution X port (AnierinB's commits) is active. Keep it short, specific,
and easy to answer.

---

Hi Bushcat, thanks a lot for keeping the T733 alive on custom ROMs —
LineageOS 23 runs great here apart from one bug I've been chasing. A few
questions, happy to test anything you throw at me:

1. **S-Pen vs. touch**: with the pen in range / pressed to the screen, the
   capacitive touch degrades and eventually dies completely until reboot;
   resting my palm while drawing also makes the pen drop input. From
   reading `lineage-22.1-gts7fewifi`: the wacom driver fires
   `NOTIFIER_TSP_BLOCKING_REQUEST/RELEASE` (TSP_STOP packets) and
   hover in/out through sec_input, but the focaltech ft820x driver never
   registers a notifier, so nothing ever pauses TSP scanning while the pen
   is active. On the Tab S7 the sec_ts driver implements exactly that
   handshake. Is that gap known? Do your newer test builds have anything
   for it, or did stock handle pen/TSP coexistence somewhere else entirely
   (TSP firmware?)? I have a patch that adds the notifier handler to
   focaltech using the existing `fts_set_scan_off()` primitive and would
   gladly test it.

2. **Kernel**: can you confirm the LOS 23.2 builds still build the kernel
   from `lineage-22.1-gts7fewifi` (the only public branch with
   `lineage-gts7fewifi_defconfig`)? And is the "kernel panic under heavy
   network usage" from the LOS 22 thread fixed in the current test builds,
   or still open? Also — is
   `android_kernel_samsung_sm7325-devicetrees@master` the maintained DTS
   source going forward, i.e. should DTS patches go there rather than the
   kernel branch's in-tree overlay dts?

3. **Evolution X**: I saw AnierinB's commit on the device tree's
   lineage-23.2 branch. Is an Evolution X build for gts7fewifi actively
   being worked on? I've got the tree building EvoX (bka) on my side with
   the same kernel/vendor pins — I don't want to step on anyone's toes, so
   if it's already in progress I'll happily just test instead.

Thanks again!

---

## What to attach / link

- The two kernel patches (`patches/kernel/0001-*.patch`,
  `0002-*.patch`) and `docs/stylus-touch-bug-analysis.md` — they show the
  exact code paths and line references, so the maintainer can verify the
  claim in a minute.
- A `dmesg` capture reproducing the bug (before patching) —
  `adb shell su -c 'dmesg' > dmesg-penbug.txt` while hovering + pressing
  the pen and resting the palm.

## If asking Samsung-source questions elsewhere

The Samsung OSS portal was down when checked ("We're doing some work on
site"). When it's back, search for **SM-T733** — the device-driver part of
the stock kernel drop would settle definitively whether stock's focaltech
driver coordinates with the wacom driver (and how), which is the one open
question in the root-cause writeup.
