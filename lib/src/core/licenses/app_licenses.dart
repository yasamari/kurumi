import 'package:flutter/foundation.dart';

/// Attribution metadata shown in the license page.
/// Keep in sync with the release notes.
class AppLicenseMeta {
  const AppLicenseMeta({
    required this.packageName,
    required this.description,
    required this.licenseText,
  });

  final String packageName;
  final String description;
  final String licenseText;
}

/// Entries Flutter does not collect automatically (native playback stack).
///
/// Dart/Flutter packages and the engine are registered by Flutter itself.
/// Full license texts (e.g. GPL) ship with the release artifacts as
/// `LICENSE` / `THIRD-PARTY-NOTICES.md`; only summaries and pointers go here.
List<AppLicenseMeta> buildAppLicenseMetas() => const [
  AppLicenseMeta(
    packageName: 'kurumi',
    description: 'kurumi itself (Copyright (C) 2026 yasamari, GPL-3.0-or-later)',
    licenseText:
        'Distributed under the GNU General Public License v3.0 or later. '
        'See the bundled LICENSE or https://www.gnu.org/licenses/gpl-3.0.html. '
        'Source code is available from the git tag of each release.',
  ),
  AppLicenseMeta(
    packageName: 'mpv / FFmpeg (Linux Nix build)',
    description: 'mpv (GPLv2+ by default) + ffmpeg-full (LGPL/GPL mix)',
    licenseText:
        'Built from nixpkgs mpv-unwrapped and ffmpeg-full via flake.nix. '
        'Corresponding source: the pinned nixpkgs revision in flake.lock and the release tag. '
        'Redistributed under the GPL. See THIRD-PARTY-NOTICES.md.',
  ),
  AppLicenseMeta(
    packageName: 'libmpv (Android custom build)',
    description: 'Jars from yasamari/libmpv-android-video-build (libaribcaption enabled)',
    licenseText:
        'Fetched by packages/media_kit_libs_android_video/android/build.gradle '
        '(e.g. tag 20260930). Corresponding source: the same tag plus the release tag. '
        'Redistributed under the FFmpeg/mpv license terms (GPL family). See THIRD-PARTY-NOTICES.md.',
  ),
  AppLicenseMeta(
    packageName: 'libmpv (Windows prebuilt)',
    description: 'mpv DLLs bundled with media_kit_libs_windows_video',
    licenseText:
        'Prebuilt DLLs from the pub.dev media_kit_libs_windows_video package (e.g. 1.0.11). '
        'Redistributed under the upstream license terms (GPL family). See THIRD-PARTY-NOTICES.md.',
  ),
  AppLicenseMeta(
    packageName: 'media_kit (Dart, MIT)',
    description: 'Copyright (c) 2021 & onwards Hitesh Kumar Saini',
    licenseText:
        'Dart code is MIT licensed (https://github.com/media-kit/media-kit). '
        'Bundled native binaries are licensed separately, as described above.',
  ),
];

/// Registers the manual entries with [LicenseRegistry]. Called from `main()`.
void registerAppLicenses() {
  final metas = buildAppLicenseMetas();
  LicenseRegistry.addLicense(() async* {
    for (final meta in metas) {
      yield LicenseEntryWithLineBreaks([meta.packageName], meta.licenseText);
    }
  });
}
