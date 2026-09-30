{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-appimage = {
      url = "github:ralismark/nix-appimage";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nix-appimage,
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

        ffmpeg-minimal = pkgs.ffmpeg-headless.override {
          withAribcaption = true;

          # 古い GPU のハードウェアデコード用 (headless では無効)。
          # libvdpau は小さく、mpv 側の vdpauSupport と対にする。
          withVdpau = true;
          # バイナリサイズ削減のため --enable-small (Android と同じ)。
          withSmallBuild = true;

          # 実行ファイル・ドキュメントは libmpv 経由の再生には不要。
          buildFfmpeg = false;
          buildFfplay = false;
          buildFfprobe = false;
          buildQtFaststart = false;
          withSdl2 = false;
          withDocumentation = false;
          withHtmlDoc = false;
          withManPages = false;
          withPodDoc = false;
          withTxtDoc = false;

          # 放送視聴に使わない外部ライブラリを削る。
          withAlsa = false;
          withAmf = false;
          withAom = false;
          withBluray = false;
          withGmp = false;
          withMp3lame = false;
          withOpenapv = false;
          withOpencl = false;
          withOpenjpeg = false;
          withOpenmpt = false;
          withRist = false;
          withSrt = false;
          withSsh = false;
          withSvtav1 = false;
          withV4l2 = false;
          withVidStab = false;
          withX264 = false;
          withX265 = false;
          withXvid = false;
          withZvbi = false;
        };
        # 上に足した自前パッチ (tsreadex 由来の字幕 PES 抽出) を当てる。
        ffmpeg-minimal-patched = ffmpeg-minimal.overrideAttrs (old: {
          patches = old.patches or [ ] ++ [
            ./mpegts-tsreadex.patch
          ];

          doCheck = false;
        });
        mpv-unwrapped-minimal = pkgs.mpv-unwrapped.override {
          ffmpeg = ffmpeg-minimal-patched;
          # 放送視聴に使わない mpv 機能を削る。音声出力 (alsa/pipewire/pulse)、
          # HW デコード (vaapi/vdpau/vulkan/drm)、描画 (x11/wayland)、
          # 色管理 (cms) は残す。
          archiveSupport = false;
          bluraySupport = false;
          cacaSupport = false;
          dvbinSupport = false;
          dvdnavSupport = false;
          javascriptSupport = false;
          openalSupport = false;
          rubberbandSupport = false;
          zimgSupport = false;
        };
        mpv-minimal = pkgs.mpv.override {
          mpv-unwrapped = mpv-unwrapped-minimal;
        };

        # media_kit_video の CMake は pkg-config で mpv/epoxy を解決する。
        # mpv.pc の Requires(.private) 解決には推移的依存の .pc も全て要るため、
        # 不足分を明示する。パッケージビルドと devShell で共有する。
        mediaKitLinuxDeps = with pkgs; [
          mpv-unwrapped-minimal
          alsa-lib
          brotli
          bzip2
          expat
          ffmpeg-minimal-patched
          fontconfig
          freetype
          fribidi
          glib
          harfbuzz
          lcms2
          libass
          libdisplay-info
          libdovi
          libdrm
          libepoxy
          libgbm
          libglvnd
          libplacebo
          libpng
          libpulseaudio
          libunwind
          libuchardet
          libva
          libvdpau
          libxkbcommon
          libxml2
          lua5_2
          nv-codec-headers
          pipewire
          shaderc
          vulkan-loader
          wayland
          wayland-protocols
          libX11
          libXext
          libXfixes
          libxpresent
          libxrandr
          libxscrnsaver
          zlib
        ];

        icon = ./android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png;

        src = lib.fileset.toSource {
          root = ./.;
          fileset = lib.fileset.unions [
            ./LICENSE
            ./THIRD-PARTY-NOTICES.md
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
          runtimeDependencies = [ mpv-unwrapped-minimal ];

          postFixup = ''
            mkdir -p $out/share/icons/hicolor/192x192/apps
            cp ${icon} $out/share/icons/hicolor/192x192/apps/kurumi.png
            # GPL の配布条件のためライセンス文書を同梱する。
            # nix-appimage は closure ごと AppImage 化するため、
            # ここに入れた文書は AppImage 内にも含まれる。
            mkdir -p $out/share/doc/kurumi
            cp ${src}/LICENSE $out/share/doc/kurumi/LICENSE
            cp ${src}/THIRD-PARTY-NOTICES.md $out/share/doc/kurumi/THIRD-PARTY-NOTICES.md
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
            description = "Mirakurun / KonomiTV 向けテレビ視聴アプリ";
            homepage = "https://github.com/yasamari/kurumi";
            license = lib.licenses.gpl3Plus;
            platforms = lib.platforms.linux;
            mainProgram = "kurumi";
          };
        };
      in
      {
        packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          inherit kurumi;
          default = kurumi;

          kurumi-appimage = nix-appimage.lib.${system}.mkAppImage {
            program = lib.getExe kurumi;
            pname = "kurumi";
          };
        };

        devShells.default = pkgs.mkShell {
          ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
          packages = [
            pkgs.flutter
            androidSdk
            pkgs.jdk17
            pkgs.pkg-config
            # 実機確認時に libmpv 解決・mpv 単体での再生試験に使う。
            mpv-minimal
            # `flutter run` 時の media_kit_video ビルド用 (mpv.pc 解決一式)。
          ]
          ++ mediaKitLinuxDeps;
        };
      }
    );
}
