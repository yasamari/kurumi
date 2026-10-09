import '../../domain/entities/cm_section.dart';

/// 自動スキップ後の着地余白 (秒)。
///
/// 終端ちょうど (`end`) に飛ぶと mpv のシーク精度で区間内に残り、再び
/// スキップが掛かってループしうる。少しだけ先に着地させる。
const cmSkipLandingOffsetSec = 0.1;

/// 再生位置が入っているCM区間を返す純粋関数。
///
/// 区間は [normalizeCmSections] 済み (昇順・重なりなし) を想定する。
/// 終端は含まない (`start <= position < end`) ため、スキップ着地点
/// (`end + offset`) では null になる。
CmSection? cmSectionAt(List<CmSection> sections, double positionSec) {
  if (!positionSec.isFinite) return null;
  for (final section in sections) {
    if (positionSec < section.startTime) break;
    if (positionSec < section.endTime) return section;
  }
  return null;
}

/// CM区間内にいるときの飛び先 (秒) を返す純粋関数。
///
/// 区間外では null。飛び先は `end + offsetSec` で、終端ちょうどに残って
/// ループしないようにする ([cmSkipLandingOffsetSec] 参照)。
double? cmSkipTargetSec(
  List<CmSection> sections,
  double positionSec, {
  double offsetSec = cmSkipLandingOffsetSec,
}) {
  final current = cmSectionAt(sections, positionSec);
  if (current == null) return null;
  return current.endTime + offsetSec;
}

/// 自動スキップすべきときの飛び先 (秒) を返す純粋関数。
///
/// [enabled] が偽のとき・区間外のときは null。設定オンなら入り方
/// (シーク流入か自然再生か) を問わず飛ばす。CMを見たいときは設定を
/// 切る運用にする。
double? cmAutoSkipTargetSec({
  required List<CmSection> sections,
  required double positionSec,
  required bool enabled,
}) {
  if (!enabled) return null;
  return cmSkipTargetSec(sections, positionSec);
}

/// シークバー表示用のCM区間の割合一覧を返す純粋関数。
///
/// 各区間を `durationSec` に対する [0, 1] の範囲に丸め、幅ゼロ・範囲外は
/// 落とす。`durationSec` が不正 (0以下・非有限) のときは空。
List<({double start, double end})> cmSectionFractions(
  List<CmSection> sections,
  double durationSec,
) {
  if (!durationSec.isFinite || durationSec <= 0) return const [];
  final fractions = <({double start, double end})>[];
  for (final section in sections) {
    final start = (section.startTime / durationSec).clamp(0.0, 1.0).toDouble();
    final end = (section.endTime / durationSec).clamp(0.0, 1.0).toDouble();
    if (end > start) fractions.add((start: start, end: end));
  }
  return fractions;
}
