# S-Pen (Wacom EMR digitizer, input device name "sec_e-pen")
#
# Userspace half of the pen/palm/touch fix — see
# docs/stylus-touch-bug-analysis.md (kernel half: patches/kernel/0001-*).
#
# LineageOS/Evolution X shipped this as `touch.deviceType = touchScreen`
# ("gets rid of the pen pointer, while retaining pen-specific functionality"
# per the original change), which makes the pen a SECOND internal touchscreen
# next to the focaltech "sec_touchscreen" device. That mis-classification
# feeds pen strokes through Android's touchscreen/palm-rejection pipeline
# and disables the stylus-aware pointer semantics.
#
# `stylus` is the correct classification for an EMR pen input device:
#  - pen events arrive as TOOL_TYPE_STYLUS with proper hover/pressure
#  - pen strokes bypass the ML palm-rejection that only applies to
#    touchscreen-classified finger streams
#  - trade-off: a hover pointer/circle is drawn again (cosmetic)
touch.deviceType = stylus
touch.orientationAware = 1
