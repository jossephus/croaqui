{
  description = "Croaqui - A Wails application with Flatpak support";

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

        # Core application derivation
        croaqui = pkgs.buildGoModule rec {
          pname = "croaqui";
          version = "0.1.0";

          src = ./.;
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

        # Flatpak manifest - dependencies resolved via Nix
        flatpak-manifest = if isLinux then
          pkgs.stdenv.mkDerivation {
            pname = "croaqui-flatpak-manifest";
            version = "0.1.0";
            src = ./.;
            
            buildInputs = with pkgs; [ jq ];
            
            buildPhase = ''
              mkdir -p $out
              cat > $out/com.github.H0lyDiv3r.croaqui.json << 'EOF'
{
  "app-id": "com.github.H0lyDiv3r.croaqui",
  "runtime": "org.gnome.Platform",
  "runtime-version": "46",
  "sdk": "org.gnome.Sdk",
  "sdk-extensions": ["org.freedesktop.Sdk.Extension.golang"],
  "command": "croaqui",
  "finish-args": [
    "--socket=wayland",
    "--socket=x11",
    "--share=ipc",
    "--device=dri",
    "--socket=pulseaudio",
    "--filesystem=home",
    "--env=LC_NUMERIC=C"
  ],
  "modules": [
    {
      "name": "taglib",
      "buildsystem": "cmake-ninja",
      "config-opts": ["-DBUILD_SHARED_LIBS=ON"],
      "sources": [
        {
          "type": "archive",
          "url": "https://taglib.org/releases/taglib-1.13.1.tar.gz",
          "sha256": "c8da2b10f1bfec2cd7dbfcd33f4a2338db0765d851a50583d410bacf055cfd0b"
        }
      ]
    },
    {
      "name": "libplacebo",
      "buildsystem": "meson",
      "config-opts": [
        "-Dvulkan=disabled",
        "-Dopengl=enabled"
      ],
      "sources": [
        {
          "type": "archive",
          "url": "https://github.com/haasn/libplacebo/archive/refs/tags/v6.338.2.tar.gz",
          "sha256": "2f1e624e09d72a8c9db70f910f7560e764a1c126dae42acc5b3bcef836a7aec6"
        }
      ]
    },
    {
      "name": "mpv",
      "buildsystem": "meson",
      "config-opts": [
        "-Dlibmpv=true",
        "-Dbuild-date=false",
        "-Dalsa=disabled"
      ],
      "cleanup": ["/share/man"],
      "sources": [
        {
          "type": "archive",
          "url": "https://github.com/mpv-player/mpv/archive/v0.37.0.tar.gz",
          "sha256": "1d2d4adbaf048a2fa6ee134575032c4b2dad9a7efafd5b3e69b88db935afaddf"
        }
      ]
    },
    {
      "name": "croaqui",
      "buildsystem": "simple",
      "build-commands": [
        "wails build -o croaqui",
        "install -Dm755 build/bin/croaqui /app/bin/croaqui"
      ],
      "sources": [
        {
          "type": "dir",
          "path": "."
        }
      ]
    }
  ]
}
EOF
            '';
          }
        else
          null;

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
              flatpak
              flatpak-builder
            ] else if isDarwin then [
              clang
              llvm
            ] else [ ]
          );

          shellHook = ''
            export PKG_CONFIG_PATH="${pkgs.taglib}/lib/pkgconfig:${pkgs.mpv}/lib/pkgconfig${if isLinux then ":${pkgs.gtk3}/lib/pkgconfig:${pkgs.webkitgtk_6_0}/lib/pkgconfig" else ""}"
          '';
        };

        packages.default = croaqui;
        
        packages.flatpak-manifest = if isLinux then flatpak-manifest else null;
      }
    );
}
