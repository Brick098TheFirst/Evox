#
# Copyright (C) 2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit device configuration
$(call inherit-product, device/samsung/gts7fewifi/device.mk)

# Inherit from the 64 bit configuration
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)

# Inherit from the common Open Source product configuration
TARGET_SUPPORTS_OMX_SERVICE := false
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)

# Inherit some Evolution X stuff
# NOTE: Evolution X syncs vendor_evolution to vendor/lineage, so the inherit
# path is vendor/lineage — not vendor/evolution. Target branch: bka
# (Android 16, lineage-23.2 based).
$(call inherit-product, vendor/lineage/config/common_full_tablet_wifionly.mk)

# Enable updating of APEXes
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

# Boot animation
TARGET_SCREEN_HEIGHT := 1600
TARGET_SCREEN_WIDTH := 2560

# Evolution X build identity
# UNOFFICIAL — this is a community build, not an Evolution-X org release.
# GApps are baked in (WITH_GMS); set WITH_GMS := false for a vanilla build
# (version string gets a "-Vanilla" suffix). EVO_MAINTAINER is kept for
# branches/variants of the vendor tree that still consume it; the name
# shown in Settings comes from the SettingsResDevice overlay
# (build_maintainer_summary).
EVO_BUILD_TYPE := Unofficial
EVO_MAINTAINER := Jayden
WITH_GMS := true

# Let Evolution X's default fingerprint spoofing (Pixel fingerprint for
# Wallet/RCS compatibility) do its thing instead of the Samsung stock
# fingerprint used by the LineageOS product. Set this to false and
# re-add PRODUCT_BUILD_PROP_OVERRIDES below to keep the Samsung one.
TARGET_ENABLE_FP_OVERRIDE := true

# Face unlock (front camera). This device has no fingerprint sensor, so
# camera face unlock is the only biometric unlock — worth having.
# (Gate consumed by vendor/lineage/config/evolution.mk.)
TARGET_SUPPORTS_64_BIT_APPS := true

## Device identifier. This must come after all inclusions
PRODUCT_NAME := evolution_gts7fewifi
PRODUCT_DEVICE := gts7fewifi
PRODUCT_BRAND := samsung
PRODUCT_MODEL := SM-T733
PRODUCT_MANUFACTURER := samsung
PRODUCT_GMS_CLIENTID_BASE := android-samsung

PRODUCT_CHARACTERISTICS := tablet

PRODUCT_SHIPPING_API_LEVEL := 30
