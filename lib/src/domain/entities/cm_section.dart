import 'package:freezed_annotation/freezed_annotation.dart';

part 'cm_section.freezed.dart';

/// CM区間 (秒)。KonomiTV の録画ファイル解析結果を表示用に持つ。
///
/// `startTime` / `endTime` は録画ファイル先頭からの秒数
/// (`RecordedVideo.cm_sections` と同じ基準)。mpv の再生位置 (秒) と
/// 直接比較できる。
@freezed
abstract class CmSection with _$CmSection {
  const factory CmSection({
    /// CM開始位置 (秒)。0以上。
    required double startTime,

    /// CM終了位置 (秒)。[startTime] より大きい。
    required double endTime,
  }) = _CmSection;
}

/// CM区間一覧を正規化する純粋関数。
///
/// 開始の昇順に並べ替え、無効な区間 (`end <= start`・負値・非有限値) を落とし、
/// 重なり・隣接する区間を結合する。上限の丸めは行わない (mpv の再生尺との
/// 突き合わせは表示側で `duration` を使って行う)。
List<CmSection> normalizeCmSections(List<CmSection> sections) {
  final valid = <CmSection>[
    for (final section in sections)
      if (section.startTime.isFinite &&
          section.endTime.isFinite &&
          section.startTime >= 0 &&
          section.endTime > section.startTime)
        section,
  ];
  valid.sort((a, b) => a.startTime.compareTo(b.startTime));
  final merged = <CmSection>[];
  for (final section in valid) {
    if (merged.isEmpty) {
      merged.add(section);
      continue;
    }
    final last = merged.last;
    if (section.startTime <= last.endTime) {
      if (section.endTime > last.endTime) {
        merged[merged.length - 1] = CmSection(
          startTime: last.startTime,
          endTime: section.endTime,
        );
      }
    } else {
      merged.add(section);
    }
  }
  return merged;
}
