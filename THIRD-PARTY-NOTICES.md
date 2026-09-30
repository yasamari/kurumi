# Third-party licenses

kurumi (Copyright (C) 2026 yasamari, GPL-3.0-or-later) bundles the open-source
software below. Releases (Android APK/AAB, Windows zip, Linux AppImage) include
this file and `LICENSE` (full GPL-3.0 text).

Source code: get it from the git tag matching the release. The tag is listed
in each release's notes. Repository: https://github.com/yasamari/kurumi

## Dart / Flutter packages

- The Flutter SDK and the packages in `pubspec.lock`
  (flutter_riverpod, go_router, dio, freezed, media_kit, media_kit_video, ...).
- Each under its own license (mostly MIT / BSD-3-Clause / Apache-2.0).
  Full texts: in-app, Settings → About → OSS licenses.
  Collected automatically at build time.

## media_kit (Dart, MIT)

- Copyright (c) 2021 & onwards Hitesh Kumar Saini <saini123hitesh@gmail.com>
- https://github.com/media-kit/media-kit
- Dart code is MIT. Native binaries below are licensed separately.

## Native playback stack (mpv / FFmpeg / libaribcaption)

Playback uses libmpv. mpv defaults to GPLv2+, FFmpeg is an LGPL/GPL mix
depending on configuration. Releases are redistributed under the GPL.

### Linux (Nix build)

- `flake.nix` builds `pkgs.mpv-unwrapped` + `pkgs.ffmpeg-full`
  (+ local `mpegts-tsreadex.patch`).
- Corresponding source: the nixpkgs revision pinned in `flake.lock`
  and the release tag.

### Android

- `packages/media_kit_libs_android_video` (MIT, vendored from media-kit)
  fetches custom jars from `yasamari/libmpv-android-video-build`
  (e.g. tag `20260930`; armeabi-v7a, arm64-v8a, x86, x86_64)
  with libaribcaption enabled in FFmpeg.
- Corresponding source: the same upstream tag plus the release tag.

### Windows

- Prebuilt mpv DLLs from the pub.dev `media_kit_libs_windows_video` package
  (e.g. 1.0.11), redistributed under the upstream license terms (GPL family).

## Fonts

- Fonts bundled with the Flutter SDK (e.g. Material Icons) keep their own
  licenses. Full texts: in-app OSS licenses page.
