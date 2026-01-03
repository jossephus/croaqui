{
  description = "Croaqui - A Wails application";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowBroken = true;
          };
          overlays = [ ];
        };
        isLinux = system == "x86_64-linux" || system == "aarch64-linux";
        isDarwin = system == "aarch64-darwin" || system == "x86_64-darwin";
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            go
            wails
            nodejs
            pkg-config
            taglib
            mpv
          ] ++ (
            if isLinux then [
              gtk3
              webkitgtk_6_0
              gcc
              libxcb
            ] else if isDarwin then [
              clang
              llvm
            ] else [ ]
          );

          shellHook = ''
            # Create symlinks for cgo to find headers and libs
            export PKG_CONFIG_PATH="${pkgs.taglib}/lib/pkgconfig:${pkgs.mpv}/lib/pkgconfig${if isLinux then ":${pkgs.gtk3}/lib/pkgconfig:${pkgs.webkitgtk_6_0}/lib/pkgconfig" else ""}"
          '';
        };

        packages.default = pkgs.buildGoModule rec {
          pname = "croaqui";
          version = "0.1.0";

          src = ./.;

          # Replace with actual vendorHash after first build
          vendorHash = null;

          nativeBuildInputs = with pkgs; [
            wails
            pkg-config
            nodejs
            clang
          ] ++ (
            if isLinux then [ gcc ] else [ ]
          );

          buildInputs = with pkgs; [
            taglib
            mpv
          ] ++ (
            if isLinux then [
              gtk3
              webkitgtk_6_0
            ] else [ ]
          );

          buildPhase = ''
            # Create symlinks for cgo to find headers and libs
            mkdir -p internals/taglib/include internals/taglib/lib
            ln -sf ${pkgs.taglib}/include/* internals/taglib/include/ 2>/dev/null || true
            ln -sf ${pkgs.mpv}/include/* internals/taglib/include/ 2>/dev/null || true
            ln -sf ${pkgs.taglib}/lib/* internals/taglib/lib/ 2>/dev/null || true
            ln -sf ${pkgs.mpv}/lib/* internals/taglib/lib/ 2>/dev/null || true

            export PKG_CONFIG_PATH="${pkgs.taglib}/lib/pkgconfig:${pkgs.mpv}/lib/pkgconfig${if isLinux then ":${pkgs.gtk3}/lib/pkgconfig:${pkgs.webkitgtk_6_0}/lib/pkgconfig" else ""}"
            export CGO_CFLAGS="-I${pkgs.taglib}/include -I${pkgs.mpv}/include"
            export CGO_LDFLAGS="-L${pkgs.taglib}/lib -L${pkgs.mpv}/lib -ltag_c -ltag -lstdc++ -lz -lm -lmpv"
            wails build -o croaqui
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp build/bin/croaqui $out/bin/
          '';

          meta = with pkgs.lib; {
            description = "Croaqui application";
            homepage = "https://github.com/H0lyDiv3r/croaqui";
            license = licenses.mit;
            platforms = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
          };
        };

        packages.flatpak = pkgs.stdenv.mkDerivation rec {
          pname = "croaqui-flatpak";
          version = "0.1.0";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            flatpak
            flatpak-builder
            rsync
          ];

          buildPhase = ''
            # Setup user Flatpak directory
            export HOME=$TMPDIR/home
            mkdir -p $HOME/.local/share/flatpak
            export XDG_DATA_HOME=$HOME/.local/share

            # Build Flatpak package
            flatpak-builder --force-clean \
              --user \
              --repo=$out/repo \
              $out/.flatpak-builder/build \
              com.github.H0lyDiv3r.croaqui.json

            # Create single-file bundle
            flatpak build-bundle $out/repo $out/com.github.H0lyDiv3r.croaqui.flatpak com.github.H0lyDiv3r.croaqui
          '';

          installPhase = ''
            mkdir -p $out
            cp -r repo $out/
            echo "Flatpak repo created at $out/repo"
            echo "Flatpak bundle created at $out/com.github.H0lyDiv3r.croaqui.flatpak"
            echo ""
            echo "To install the bundle, run:"
            echo "  flatpak install --user $out/com.github.H0lyDiv3r.croaqui.flatpak"
            echo ""
            echo "Or add as remote and install:"
            echo "  flatpak remote-add --if-not-exists croaqui $out/repo --no-gpg-verify"
            echo "  flatpak install croaqui com.github.H0lyDiv3r.croaqui"
          '';

          meta = with pkgs.lib; {
            description = "Croaqui Flatpak package";
            homepage = "https://github.com/H0lyDiv3r/croaqui";
            license = licenses.mit;
            platforms = [ "x86_64-linux" "aarch64-linux" ];
          };
        } // (if isDarwin then { } else { });

        packages.flatpakRepo = pkgs.stdenv.mkDerivation rec {
          pname = "croaqui-flatpak-repo";
          version = "0.1.0";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            flatpak
            flatpak-builder
            rsync
          ];

          buildPhase = ''
            # Setup user Flatpak directory
            export HOME=$TMPDIR/home
            mkdir -p $HOME/.local/share/flatpak
            export XDG_DATA_HOME=$HOME/.local/share

            flatpak-builder --force-clean \
              --user \
              --repo=$out/repo \
              $out/.flatpak-builder/build \
              com.github.H0lyDiv3r.croaqui.json
          '';

          installPhase = ''
            mkdir -p $out
            cp -r repo $out/
          '';

          meta = with pkgs.lib; {
            description = "Croaqui Flatpak repository";
            homepage = "https://github.com/H0lyDiv3r/croaqui";
            license = licenses.mit;
            platforms = [ "x86_64-linux" "aarch64-linux" ];
          };
        } // (if isDarwin then { } else { });
      }
    );
}
