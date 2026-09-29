{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        lib = nixpkgs.lib;

        pkgs = import nixpkgs {
          inherit system;
          config = {
            android_sdk.accept_license = true;
            allowUnfree = true;
          };
        };

        androidPackages = pkgs.androidenv.composeAndroidPackages {
          buildToolsVersions = [ "36.0.0" ];
          platformVersions = [ "36" ];
          includeCmake = true;
          includeNDK = true;
          ndkVersions = [ "28.2.13676358" ];
          includeEmulator = true;
          includeSystemImages = true;
          systemImageTypes = [ "google_apis" ];
          abiVersions = [ "x86_64" ];
          includeExtras = [ ];
          includeSources = false;
        };
        androidSdk = androidPackages.androidsdk;

        # media_kit は Linux ではシステムの libmpv を dlopen するため、
        # ffmpeg フル機能版でビルドした mpv を用意する。
        # mpv 0.41 は ffmpeg 9 に対応済み (既定の ffmpeg と同メジャー) のため、
        # ffmpeg-full (9.x) への差し替えは ABI 互換の範囲内である。
        mpv-unwrapped-full = pkgs.mpv-unwrapped.override {
          ffmpeg = pkgs.ffmpeg-full.overrideAttrs (old: {
            patches = old.patches or [ ] ++ [
              ./mpegts-tsreadex.patch
            ];

            doCheck = false;
          });
        };
        mpv-full = pkgs.mpv.override {
          mpv-unwrapped = mpv-unwrapped-full;
        };

        # media_kit_video の CMake は pkg-config で mpv/epoxy を解決する。
        # mpv.pc の Requires(.private) 解決には推移的依存の .pc も全て要るため、
        # 不足分を明示する。パッケージビルドと devShell で共有する。
        mediaKitLinuxDeps = with pkgs; [
          mpv-unwrapped-full
          alsa-lib
          brotli
          bzip2
          expat
          ffmpeg-full
          fontconfig
          freetype
          fribidi
          glib
          harfbuzz
          lcms2
          libarchive
          libass
          libbluray
          libcaca
          libdisplay-info
          libdrm
          libdvdnav
          libepoxy
          libgbm
          libglvnd
          libplacebo
          libpng
          libpulseaudio
          libuchardet
          libva
          libvdpau
          libxkbcommon
          libxml2
          lua5_2
          mujs
          nv-codec-headers
          openal-soft
          pipewire
          rubberband
          vulkan-loader
          wayland
          wayland-protocols
          libX11
          libXext
          libXfixes
          libxpresent
          libxrandr
          libxscrnsaver
          zimg
          zlib
        ];

        icon = ./android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png;

        src = lib.fileset.toSource {
          root = ./.;
          fileset = lib.fileset.unions [
            ./analysis_options.yaml
            ./lib
            ./linux
            # dependency_overrides の path 依存。Android ビルド以外では
            # 参照されないが、pub get 解決時に必ず実在が要求される。
            ./packages
            ./pubspec.lock
            ./pubspec.yaml
            icon
          ];
        };

        kurumi = pkgs.flutter.buildFlutterApplication {
          pname = "kurumi";
          version = "1.0.0";
          inherit src;

          autoPubspecLock = ./pubspec.lock;

          gitHashes = { };

          nativeBuildInputs = [ pkgs.copyDesktopItems ];

          # media_kit_video プラグインのビルドに libmpv のヘッダーが必要。
          # mpv.pc の推移的 Requires 解決用に mediaKitLinuxDeps をまとめて載せる。
          buildInputs = mediaKitLinuxDeps;

          # media_kit は Linux ではシステムの libmpv を dlopen する。
          # dart:ffi の DynamicLibrary.open() は RUNPATH を見ないため、
          # builder 標準の runtimeDependencies で LD_LIBRARY_PATH に載せる。
          runtimeDependencies = [ mpv-unwrapped-full ];

          postFixup = ''
            mkdir -p $out/share/icons/hicolor/192x192/apps
            cp ${icon} $out/share/icons/hicolor/192x192/apps/kurumi.png
          '';

          desktopItems = [
            (pkgs.makeDesktopItem {
              name = "kurumi";
              exec = "kurumi";
              icon = "kurumi";
              desktopName = "Kurumi";
              categories = [
                "Video"
                "TV"
              ];
            })
          ];

          meta = {
            platforms = lib.platforms.linux;
            mainProgram = "kurumi";
          };
        };
      in
      {
        packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          inherit kurumi;
          default = kurumi;
        };

        devShells.default = pkgs.mkShell {
          ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
          packages = [
            pkgs.flutter
            androidSdk
            pkgs.jdk17
            pkgs.pkg-config
            # 実機確認時に libmpv 解決・mpv 単体での再生試験に使う。
            mpv-full
            # `flutter run` 時の media_kit_video ビルド用 (mpv.pc 解決一式)。
          ]
          ++ mediaKitLinuxDeps;
        };
      }
    );
}
