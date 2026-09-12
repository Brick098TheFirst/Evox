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

# ---------------------------------------------------------------------------
# Evolution X options.
#
# IMPORTANT: these MUST stay ABOVE the vendor inherit below. The vendor's
# evolution.mk / version.mk (pulled in through common_full_tablet_wifionly.mk)
# evaluate ifeq() at parse time, i.e. exactly when the inherit line below is
# expanded — flags set after it would be silently ignored. This matches how
# official Evolution-X device trees order their product files.
# ---------------------------------------------------------------------------

# Build identity — UNOFFICIAL community build.
# GApps are baked in (WITH_GMS); set to false for a vanilla build (the
# version string then gets a "-Vanilla" suffix).
EVO_BUILD_TYPE := Unofficial
EVO_MAINTAINER := Jayden
WITH_GMS := true

# Keep Evolution X's default fingerprint spoof (Pixel fingerprint, helps
# Wallet/RCS). Set to false and re-add the Samsung PRODUCT_BUILD_PROP_OVERRIDES
# from lineage_gts7fewifi.mk if you prefer the stock Samsung identity.
TARGET_ENABLE_FP_OVERRIDE := true

# Face unlock (front camera). The T733 has no fingerprint sensor, so camera
# face unlock is the only biometric unlock — gate consumed by evolution.mk.
TARGET_SUPPORTS_64_BIT_APPS := true

# Boot animation (also drives Evolution X's generated bootanimation)
TARGET_SCREEN_HEIGHT := 1600
TARGET_SCREEN_WIDTH := 2560

# Inherit some Evolution X stuff.
# NOTE: Evolution X syncs vendor_evolution to vendor/lineage, so the inherit
# path is vendor/lineage — not vendor/evolution. Target branch: bka
# (Android 16, lineage-23.2 based).
$(call inherit-product, vendor/lineage/config/common_full_tablet_wifionly.mk)

# Enable updating of APEXes
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

## Device identifier. This must come after all inclusions
PRODUCT_NAME := evolution_gts7fewifi
PRODUCT_DEVICE := gts7fewifi
PRODUCT_BRAND := samsung
PRODUCT_MODEL := SM-T733
PRODUCT_MANUFACTURER := samsung
PRODUCT_GMS_CLIENTID_BASE := android-samsung

PRODUCT_CHARACTERISTICS := tablet

PRODUCT_SHIPPING_API_LEVEL := 30
