#!/usr/bin/env bash
# Apply the see-through noscreenshare patch to a Hyprland source tree.
# Auto-detects the renderer API generation and picks the right patch.
#
# Usage:
#   ./apply.sh [path-to-hyprland-checkout]
#   ./apply.sh --check [path]   # dry run only
#   ./apply.sh --reverse [path] # revert the patch
#
# Requirements: git apply (part of git). No network, no build, no launch.
set -u

CHECK_ONLY=0
REVERSE=0
TARGET="."

for arg in "$@"; do
    case "$arg" in
        --check)   CHECK_ONLY=1 ;;
        --reverse) REVERSE=1 ;;
        *)         TARGET="$arg" ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$SCRIPT_DIR/patches"

if [ ! -d "$TARGET/src" ]; then
    echo "error: '$TARGET' does not look like a Hyprland checkout (no src/ dir)" >&2
    exit 2
fi

# Detect API generation:
#   new (CRenderContext): src/render/Context.hpp exists AND
#       ScreenshareFrame.cpp uses Render::CRenderContext
#   legacy (m_renderData): otherwise
PATCH=""
if [ -f "$TARGET/src/render/Context.hpp" ] && \
   grep -q "CRenderContext" "$TARGET/src/managers/screenshare/ScreenshareFrame.cpp" 2>/dev/null; then
    PATCH="$PATCH_DIR/see-through-context-api.patch"
    GEN="context-api (CRenderContext)"
else
    PATCH="$PATCH_DIR/see-through-legacy-api.patch"
    GEN="legacy (m_renderData / IHyprRenderer fields)"
fi

if [ ! -f "$PATCH" ]; then
    echo "error: patch file missing: $PATCH" >&2
    exit 2
fi

# Bail out early if already applied (idempotent re-runs).
if git -C "$TARGET" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
    if [ "$REVERSE" = 1 ]; then
        ACTION="git apply --reverse (revert)"
    else
        echo "already applied ($GEN): nothing to do."
        exit 0
    fi
else
    if [ "$REVERSE" = 1 ]; then
        echo "patch does not appear to be applied: nothing to revert." >&2
        exit 1
    fi
    ACTION="git apply"
fi

echo "target: $TARGET"
echo "api:    $GEN"
echo "patch:  $PATCH"

if [ "$CHECK_ONLY" = 1 ]; then
    if [ "$REVERSE" = 1 ]; then
        git -C "$TARGET" apply --reverse --check -v "$PATCH"
    else
        git -C "$TARGET" apply --check -v "$PATCH"
    fi
    echo "dry-run OK."
    exit 0
fi

if [ "$REVERSE" = 1 ]; then
    git -C "$TARGET" apply --reverse -v "$PATCH"
else
    git -C "$TARGET" apply -v "$PATCH"
fi
echo "applied."
