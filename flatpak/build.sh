#!/usr/bin/env bash
# Build Croaqui Flatpak using Nix-resolved dependencies

set -e

MANIFEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$MANIFEST_DIR")"
MANIFEST="$MANIFEST_DIR/com.github.H0lyDiv3r.croaqui.json"
BUILD_DIR="/tmp/croaqui-flatpak-build"
REPO_DIR="/tmp/croaqui-flatpak-repo"

echo "Building Croaqui Flatpak..."
echo "Manifest: $MANIFEST"
echo "Build directory: $BUILD_DIR"

# Generate manifest from Nix
echo "[1/3] Generating Flatpak manifest from Nix..."
nix build "$PROJECT_ROOT#flatpak-manifest" -o nix-flatpak-manifest
cp nix-flatpak-manifest/com.github.H0lyDiv3r.croaqui.json "$MANIFEST"

# Initialize build directory
if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"

# Build using flatpak-builder
echo "[2/3] Building with flatpak-builder..."
flatpak-builder --force-clean --default-branch=master \
    --ccache \
    "$BUILD_DIR" \
    "$MANIFEST"

# Create repository
if [ -d "$REPO_DIR" ]; then
    rm -rf "$REPO_DIR"
fi
mkdir -p "$REPO_DIR"

echo "[3/3] Creating Flatpak repository..."
flatpak build-export "$REPO_DIR" "$BUILD_DIR" master

echo ""
echo "✓ Flatpak built successfully!"
echo ""
echo "To install:"
echo "  flatpak remote-add --no-gpg-verify croaqui-local file://$REPO_DIR"
echo "  flatpak install croaqui-local com.github.H0lyDiv3r.croaqui"
echo ""
echo "To run:"
echo "  flatpak run com.github.H0lyDiv3r.croaqui"
