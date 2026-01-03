# Flatpak Packaging for Croaqui

This directory contains Flatpak configuration and build tools for Croaqui.

## How It Works

The build process uses **Nix to resolve all dependencies** and then builds the Flatpak:

1. **Nix flake** (`flake.nix`) defines all build dependencies (Go, Wails, taglib, mpv, etc.)
2. **Nix generates** the Flatpak manifest with proper module definitions
3. **flatpak-builder** uses the manifest to build the actual Flatpak bundle
4. All dependencies are versioned and pinned via the flake lock file

This ensures reproducibility - the same versions are used in both the native build and Flatpak.

## Building

### Prerequisites

```bash
# Install on Fedora/RHEL
sudo dnf install flatpak flatpak-builder

# Install on Debian/Ubuntu
sudo apt install flatpak flatpak-builder

# Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### Build Steps

```bash
cd /path/to/croaqui

# Build the Flatpak
flatpak/build.sh

# Install locally
flatpak remote-add --no-gpg-verify croaqui-local file:///tmp/croaqui-flatpak-repo
flatpak install croaqui-local com.github.H0lyDiv3r.croaqui

# Run it
flatpak run com.github.H0lyDiv3r.croaqui
```

## Files

- **build.sh** - Main build script (Nix → Flatpak)
- **com.github.H0lyDiv3r.croaqui.json** - Generated manifest (DO NOT edit)
- **com.github.H0lyDiv3r.croaqui.desktop** - Desktop entry
- **com.github.H0lyDiv3r.croaqui.metainfo.xml** - AppData metadata

## Nix Integration

The flake exposes:

```bash
# Build native package
nix build .#default

# Generate Flatpak manifest
nix build .#flatpak-manifest

# Enter dev shell with all tools
nix flake develop
```

## Why This Approach?

- **Reproducible**: Same Nix pins for native and Flatpak
- **Pure**: No manual dependency hunting
- **Maintainable**: Single source of truth (flake.nix)
- **Canonical**: Uses flatpak-builder as intended
- **Reliable**: Dependencies tested in native build first
