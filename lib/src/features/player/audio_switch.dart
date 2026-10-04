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
/// (ストリームは通常のステレオと区別が付かない)。そのため **EIT[p/f] の音声
/// コンポーネント記述子 (0xC4)** から判定する ([LiveAudioLayout])。ただし
/// 判定できるのは主・副の切替が要るかどうかだけで、マルチチャンネルなどは
/// mpv の音声トラック認識に委ねる ([audioMenuMode])。
///
/// このモジュールは「どれを選ぶか」と「mpv にどう伝えるか」だけを担う。
library;

import 'package:media_kit/media_kit.dart';

import '../../data/ts/audio_layout.dart';

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
/// そのままステレオ出力する (L=主 / R=副) になる。メニューはこの値を選ばせず、
/// 判定できた時点で主音声 ([DualMonoChannel.main]) を適用する。
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
/// タイトル → 言語 → 主音声/副音声の順にフォールバックする。放送TSでは通常
/// タイトルも言語も空で、二重ステレオは1本目が主音声・2本目が副音声のため、
/// その表示にする。3本目以降は `音声N`。
String audioTrackLabel({String? title, String? language, required int index}) {
  final t = title?.trim();
  if (t != null && t.isNotEmpty) return t;
  final l = language?.trim();
  if (l != null && l.isNotEmpty) return l;
  return switch (index) {
    1 => '主音声',
    2 => '副音声',
    _ => '音声$index',
  };
}

/// 再生中の音声トラックの位置を返す。
///
/// [current] が [tracks] にあればその位置。`auto` 選択中などで一覧に無い
/// ときは先頭を返す (mpv の `auto` は最初のトラックを選択する)。空なら -1。
int currentAudioTrackIndex({
  required List<AudioTrack> tracks,
  required AudioTrack current,
}) {
  final index = tracks.indexWhere((t) => t.id == current.id);
  if (index >= 0) return index;
  return tracks.isEmpty ? -1 : 0;
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

/// 二重モノラルの復号チャンネルを選ぶ。
///
/// null (既定 = 主＋副をステレオ出力) は選択肢として出さない。場面では
/// [LiveAudioLayout.dualMono] と判定された時点で主音声を適用する。
final class DualMonoChoice extends AudioChoice {
  const DualMonoChoice(this.channel);

  final DualMonoChannel? channel;
}

/// 音声ページで何を見せるか。
enum AudioMenuMode {
  /// mpv が得た音声トラックを一覧する (二重ステレオなど)。
  tracks,

  /// 主音声・副音声だけを選ぶ (デュアルモノラル)。
  dualMono,

  /// 選べない。1行だけ表示する。
  single,
}

/// 音声ページの表示方法を決める。
///
/// mpv の音声トラックを最優先する。KonomiTV の再エンコード画質は元の放送が
/// デュアルモノラルでも、右チャンネルを副音声トラックに分離して**2本**出すため、
/// EIT の判定より mpv の認識を優先しないと `dual_mono_mode` の効かない
/// 選択になる。
///
/// 音声が1本だけのときだけ [layout] を見る。判定できない
/// ([LiveAudioLayout.unknown] = 録画再生・マルチチャンネルなど) か主音声のみ
/// ([LiveAudioLayout.mainAudioOnly]) なら [AudioMenuMode.single]。
AudioMenuMode audioMenuMode({
  required int realAudioTrackCount,
  required LiveAudioLayout layout,
}) {
  if (realAudioTrackCount > 1) return AudioMenuMode.tracks;
  if (layout == LiveAudioLayout.dualMono) return AudioMenuMode.dualMono;
  return AudioMenuMode.single;
}

/// 音声ページ・一覧に出す現在の音声の表示名。
String audioMenuLabel({
  required AudioMenuMode mode,
  required LiveAudioLayout layout,
  required List<AudioTrack> realAudioTracks,
  required AudioTrack current,
  required DualMonoChannel? dualMonoChannel,
}) {
  switch (mode) {
    case AudioMenuMode.tracks:
      // `auto` 選択中などで現在値が一覧に無くても先頭 (再生中) を表示する。
      final index = currentAudioTrackIndex(
        tracks: realAudioTracks,
        current: current,
      );
      if (index < 0) return '切替';
      return audioTrackLabel(
        title: realAudioTracks[index].title,
        language: realAudioTracks[index].language,
        index: index + 1,
      );
    case AudioMenuMode.dualMono:
      // 判定できた時点で主音声へ倒すため、未選択は主音声として扱う。
      return dualMonoChannel?.label ?? DualMonoChannel.main.label;
    case AudioMenuMode.single:
      if (layout == LiveAudioLayout.mainAudioOnly) {
        return DualMonoChannel.main.label;
      }
      // 判定できない場合は mpv の認識をそのまま出す (無ければ主音声)。
      final first = realAudioTracks.isEmpty ? null : realAudioTracks.first;
      if (first == null) return DualMonoChannel.main.label;
      return audioTrackLabel(
        title: first.title,
        language: first.language,
        index: 1,
      );
  }
}
