/// 音声切り替えの純粋ロジック。
///
/// テレビ放送の音声は大きく2通りある:
///
/// - 二重ステレオ: 主音声・副音声がそれぞれ独立した音声トラックとして
///   多重化される。mpv はこれを通常の音声トラックとして扱うため、トラックを
///   選び直すだけで切り替えられる ([AudioTrackChoice])。
/// - 二重モノラル: 1本のステレオ音声 (L=主音声 / R=副音声) に主副が同居する。
///   mpv のトラック選択では分離できないため、libavcodec のデコーダオプション
///   `dual_mono_mode` でどちらのチャンネルを復号するかを指定する
///   ([dualMonoLavcOption] / [DualMonoChoice])。通常ステレオでは無効 (no-op)。
///
/// 二重モノラルかどうかはコンテナ (PMT) からは判定できない
/// (ストリームは通常のステレオと区別が付かない) ため、このモジュールは
/// 「切り替えたい値」を mpv に渡せる形へ変換するところまでを担う。
library;

/// 二重モノラルで復号するチャンネル。
enum DualMonoChannel {
  /// 主音声 (Lch)。
  main,

  /// 副音声 (Rch)。
  sub,
}

extension DualMonoChannelX on DualMonoChannel {
  /// メニューなどに出す表示名。
  String get label => switch (this) {
    DualMonoChannel.main => '主音声',
    DualMonoChannel.sub => '副音声',
  };
}

/// libavcodec の `dual_mono_mode` に渡す値。
///
/// [channel] が null のときは既定 (`auto`)。二重モノラルでは `auto` は主副を
/// そのままステレオ出力する (L=主 / R=副) ため、「主＋副」の表示に対応する。
String dualMonoModeValue(DualMonoChannel? channel) => switch (channel) {
  DualMonoChannel.main => 'main',
  DualMonoChannel.sub => 'sub',
  null => 'auto',
};

/// mpv の `ad-lavc-o` プロパティに設定する文字列。
String dualMonoLavcOption(DualMonoChannel? channel) =>
    'dual_mono_mode=${dualMonoModeValue(channel)}';

/// 音声トラックのメニュー表示名。
///
/// タイトル → 言語 → `音声N` の順にフォールバックする。放送TSでは通常どちらも
/// 空なので、多くの場合 `音声N` になる。
String audioTrackLabel({String? title, String? language, required int index}) {
  final t = title?.trim();
  if (t != null && t.isNotEmpty) return t;
  final l = language?.trim();
  if (l != null && l.isNotEmpty) return l;
  return '音声$index';
}

/// 音声メニューの選択結果。
sealed class AudioChoice {
  const AudioChoice();
}

/// mpv の音声トラックを選ぶ (二重ステレオなど)。
final class AudioTrackChoice extends AudioChoice {
  const AudioTrackChoice(this.trackId);

  /// mpv のトラック ID。
  final String trackId;
}

/// 二重モノラルの復号チャンネルを選ぶ。null は既定 (主＋副をステレオ出力)。
final class DualMonoChoice extends AudioChoice {
  const DualMonoChoice(this.channel);

  final DualMonoChannel? channel;
}
