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
          includeEmulator = true;
          includeSystemImages = true;
          systemImageTypes = [ "google_apis" ];
          abiVersions = [ "x86_64" ];
          includeExtras = [ ];
          includeSources = false;
        };
        androidSdk = androidPackages.androidsdk;

        icon = ./android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png;

        src = lib.fileset.toSource {
          root = ./.;
          fileset = lib.fileset.unions [
            ./analysis_options.yaml
            ./lib
            ./linux
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
          packages = with pkgs; [
            flutter
            androidSdk
            jdk17
            pkg-config
          ];
        };
      }
    );
}
