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
      in
      {
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
