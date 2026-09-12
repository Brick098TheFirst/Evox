#!/usr/bin/env bash
#
# setup-build.sh — one-shot build setup for the Galaxy Tab S7 FE (gts7fewifi)
#
# Clones everything (no forks needed anywhere), transfers the S-Pen/touch
# kernel patches onto the kernel checkout, and starts the build.
#
#   Evolution X (default):   ./scripts/setup-build.sh
#   LineageOS 23.2 instead:  ./scripts/setup-build.sh --rom lineage
#   Just prepare, no build:  ./scripts/setup-build.sh --sync-only
#   Re-apply kernel patches  ./scripts/setup-build.sh --patches-only
#                            (use this if a later repo sync reset the
#                             kernel repo and dropped the patch commits)
#
# Environment overrides:
#   WORKDIR=<dir>        build tree location   (default: ~/gts7fewifi-<rom>)
#   VARIANT=<variant>    userdebug | user | eng (default: userdebug)
#   DEVICE_BRANCH=<ref>  branch of Brick098TheFirst/Evox to use as the
#                        device tree (default: arena/01a09644-evox)
#   JOBS=<n>             sync/build parallelism (default: nproc)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ROM="evox"
SYNC_ONLY="no"
PATCHES_ONLY="no"
BUILD_ONLY="no"

while [ $# -gt 0 ]; do
    case "$1" in
        --rom=*)        ROM="${1#*=}" ;;
        --rom)          ROM="$2"; shift ;;
        --sync-only)    SYNC_ONLY="yes" ;;
        --patches-only) PATCHES_ONLY="yes" ;;
        --build-only)   BUILD_ONLY="yes" ;;
        -h|--help)      sed -n '2,/^[^#]/p' "$0" | grep '^#' | grep -v '^#!' | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1 (see --help)" >&2; exit 1 ;;
    esac
    shift
done

case "$ROM" in
    evox)    MANIFEST_URL="https://github.com/Evolution-X/manifest"; MANIFEST_BRANCH="bka" ;;
    lineage) MANIFEST_URL="https://github.com/LineageOS/android";    MANIFEST_BRANCH="lineage-23.2" ;;
    *) echo "Invalid --rom '$ROM' (use: evox | lineage)" >&2; exit 1 ;;
esac

WORKDIR="${WORKDIR:-$HOME/gts7fewifi-$ROM}"
VARIANT="${VARIANT:-userdebug}"
DEVICE_BRANCH="${DEVICE_BRANCH:-arena/01a09644-evox}"
JOBS="${JOBS:-$(nproc)}"
KERNEL_DIR="$WORKDIR/kernel/samsung/sm7325"
LOCAL_MANIFEST_SRC="$REPO_ROOT/docs/local_manifests/gts7fewifi.xml"
LOCAL_MANIFEST_DST="$WORKDIR/.repo/local_manifests/gts7fewifi.xml"
PATCHES=( "$REPO_ROOT"/patches/kernel/*.patch )

log()  { printf '\033[1;32m>>>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m>>> WARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m>>> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- checks ---
command -v git     >/dev/null || die "git not found — install it first"
command -v python3 >/dev/null || die "python3 not found — install it first"

if [ "$PATCHES_ONLY" = "yes" ] || [ "$BUILD_ONLY" = "yes" ]; then
    # No sync will run — repo and git-lfs are not needed.
    :
else
    if ! command -v repo >/dev/null; then
        log "'repo' not found, installing to ~/.local/bin ..."
        mkdir -p "$HOME/.local/bin"
        curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo \
            -o "$HOME/.local/bin/repo"
        chmod a+x "$HOME/.local/bin/repo"
        export PATH="$HOME/.local/bin:$PATH"
        grep -q '.local/bin' ~/.profile 2>/dev/null || \
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
    fi

    command -v git-lfs >/dev/null || warn \
        "git-lfs not found — repo init --git-lfs may fail. Install git-lfs first."
fi

[ -f "$LOCAL_MANIFEST_SRC" ] || die "missing $LOCAL_MANIFEST_SRC (run this script from a full Evox checkout)"
if [ ! -f "${PATCHES[0]}" ]; then
    die "no kernel patches found in $REPO_ROOT/patches/kernel"
fi

apply_patches() {
    [ -d "$KERNEL_DIR" ] || die "$KERNEL_DIR not found — run a full setup first"

    # Idempotency: if the patches can be reverse-applied, they're already in.
    if ( cd "$KERNEL_DIR" && git apply --check -R "${PATCHES[@]}" 2>/dev/null ); then
        log "Kernel patches already present, nothing to do"
        return 0
    fi

    log "Applying S-Pen/touch kernel patches in $KERNEL_DIR"
    if ( cd "$KERNEL_DIR" && git am --3way "${PATCHES[@]}" 2>/dev/null ); then
        ( cd "$KERNEL_DIR" && git log --oneline -2 )
    else
        ( cd "$KERNEL_DIR" && git am --abort ) 2>/dev/null || true
        if ( cd "$KERNEL_DIR" && git apply "${PATCHES[@]}" ); then
            warn "git am failed (no git identity?) — applied to the working tree with git apply instead"
        else
            die "could not apply kernel patches — inspect $KERNEL_DIR manually"
        fi
    fi
}

# ----------------------------------------------------------- patches-only ---
if [ "$PATCHES_ONLY" = "yes" ]; then
    apply_patches
    exit 0
fi

# ------------------------------------------------------------------ sync ----
if [ "$BUILD_ONLY" = "no" ]; then
    log "ROM:         $ROM  ($MANIFEST_URL @ $MANIFEST_BRANCH)"
    log "Workdir:     $WORKDIR"
    log "Device tree: Brick098TheFirst/Evox @ $DEVICE_BRANCH"
    warn "A full sync is roughly 50-100 GB and can take an hour or more."

    mkdir -p "$WORKDIR"
    cd "$WORKDIR"

    log "repo init"
    repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --git-lfs

    log "Installing local manifest (all device repos pinned)"
    mkdir -p .repo/local_manifests
    if [ "$DEVICE_BRANCH" = "arena/01a09644-evox" ]; then
        cp "$LOCAL_MANIFEST_SRC" "$LOCAL_MANIFEST_DST"
    else
        sed "s#refs/heads/arena/01a09644-evox#refs/heads/$DEVICE_BRANCH#" \
            "$LOCAL_MANIFEST_SRC" > "$LOCAL_MANIFEST_DST"
    fi

    log "repo sync (this is the long part)"
    repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags

    apply_patches

    if [ "$SYNC_ONLY" = "yes" ]; then
        log "Sync + patches done. Build later with:"
        log "  $0 --build-only --rom $ROM"
        exit 0
    fi
else
    cd "$WORKDIR"
fi

# ----------------------------------------------------------------- build ----
case "$ROM" in
    evox)    TARGET="evolution_gts7fewifi"; BUILD_TARGET="evolution" ;;
    lineage) TARGET="lineage_gts7fewifi";   BUILD_TARGET="bacon" ;;
esac

log "Building $TARGET-$VARIANT"
# envsetup/lunch are not 'set -u' clean
set +u
source build/envsetup.sh
lunch "$TARGET-$VARIANT"
m "$BUILD_TARGET"
