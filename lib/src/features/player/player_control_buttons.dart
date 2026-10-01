import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';

import 'audio_switch.dart';

/// プレイヤー画面の戻るボタン。ライブ視聴と録画再生で共有する。
class PlayerBackButton extends StatelessWidget {
  const PlayerBackButton({super.key, this.fallbackPath = '/tv'});

  /// 戻る遷移先が無いときのフォールバックパス。
  final String fallbackPath;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallbackPath);
        }
      },
      icon: const Icon(Icons.arrow_back),
      color: Colors.white,
      tooltip: '戻る',
    );
  }
}

/// 画質切替ボタン。ライブ視聴と録画再生で共有する。
///
/// `PopupMenuButton` は使わない。media_kit のコントロールは自動非表示に
/// なると `mount=false` としてツリーから取り除かれるため、メニュー選択時点で
/// このウィジェットが破棄されていることがある。その場合 Flutter 内部の
/// `if (!mounted) return;` により `onSelected` が呼ばれず、画質が切り替わらない。
/// そのため `showMenu` を直接呼び、選択結果をコールバックで返す。呼び出し側
/// (コントロールより上位のウィジェット) で状態に反映すること。
class QualityMenuButton extends StatelessWidget {
  const QualityMenuButton({
    super.key,
    required this.current,
    required this.qualities,
    required this.onSelected,
  });

  /// 現在の画質。
  final String current;

  /// 選択肢の画質一覧。
  final List<String> qualities;

  /// 画質選択時のコールバック。
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.high_quality_outlined),
      color: Colors.white,
      tooltip: '画質切替',
      onPressed: () => _showQualityMenu(context),
    );
  }

  /// 画質選択メニューを表示し、選択結果を [onSelected] で返す。
  Future<void> _showQualityMenu(BuildContext context) async {
    final anchorBox = context.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.hasSize) return;
    if (overlayBox == null || !overlayBox.hasSize) return;

    final origin = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final selected = await showMenu<String>(
      context: context,
      // `PopupMenuButton` の既定位置指定に合わせる (ボタン直下・左右16px)。
      position: RelativeRect.fromLTRB(
        origin.dx + 16,
        origin.dy + anchorBox.size.height,
        overlayBox.size.width - origin.dx - anchorBox.size.width - 16,
        overlayBox.size.height - origin.dy - anchorBox.size.height,
      ),
      items: [
        for (final q in qualities)
          CheckedPopupMenuItem<String>(
            value: q,
            checked: q == current,
            child: Text(q),
          ),
      ],
    );
    if (selected == null) return;
    onSelected(selected);
  }
}

/// 字幕表示のオンオフ切替ボタン (ARIB字幕など)。ライブ視聴と録画再生で共有する。
class SubtitleToggleButton extends StatelessWidget {
  const SubtitleToggleButton({super.key, required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Track>(
      stream: player.stream.track,
      builder: (context, snapshot) {
        final current =
            snapshot.data?.subtitle ?? player.state.track.subtitle;
        final isOff = current.id == SubtitleTrack.no().id;
        return IconButton(
          icon: Icon(
            isOff
                ? Icons.closed_caption_off_outlined
                : Icons.closed_caption,
          ),
          color: Colors.white,
          tooltip: isOff ? '字幕を表示' : '字幕を非表示',
          onPressed: () => player.setSubtitleTrack(
            isOff ? SubtitleTrack.auto() : SubtitleTrack.no(),
          ),
        );
      },
    );
  }
}

/// 二重モノラルの主/副音声を mpv に適用する。ライブ視聴と録画再生で共有する。
///
/// `dual_mono_mode` は音声デコーダの生成時に読まれるため、`ad-lavc-o` を
/// 設定しただけでは反映されない。`audio-reload` で音声デコーダを作り直すと
/// 反映される (映像・ストリーム接続はそのまま維持される)。
/// [channel] が null のときは既定 (`auto`、主＋副をステレオ出力) に戻す。
///
/// 通常ステレオでは `dual_mono_mode` は無効なため、誤って設定しても音は
/// 変わらない ([audio_switch.dart] 参照)。
Future<void> applyDualMonoChannel(
  Player player,
  DualMonoChannel? channel,
) async {
  final platform = player.platform;
  // web版など mpv を直接扱えない環境では何もしない。
  if (platform is! NativePlayer) return;
  await platform.setProperty('ad-lavc-o', dualMonoLavcOption(channel));
  await platform.command(['audio-reload']);
}

/// 音声切替ボタン。ライブ視聴と録画再生で共有する。
///
/// メニューの内容は mpv の音声トラック数で決める:
///
/// - 複数あるとき (二重ステレオ) はトラック一覧を出し、選ぶと
///   [Player.setAudioTrack] で切り替える。
/// - 1本だけのとき (二重モノラルの可能性) は「ステレオ(主＋副)/主音声/
///   副音声」を出し、[applyDualMonoChannel] でデコーダを作り直す。
///   通常ステレオでは無効だが、コンテナからは二重モノラルと区別できない
///   ため常に出す。
///
/// `PopupMenuButton` は使わない。media_kit のコントロールは自動非表示に
/// なると `mount=false` としてツリーから取り除かれるため、メニュー選択時点で
/// このウィジェットが破棄されていることがある。その場合 Flutter 内部の
/// `if (!mounted) return;` により `onSelected` が呼ばれず、選択が反映されない。
/// そのため `showMenu` を直接呼び、選択結果をコールバックで返す。
class AudioMenuButton extends StatelessWidget {
  const AudioMenuButton({
    super.key,
    required this.player,
    required this.dualMonoChannel,
    required this.onSelected,
  });

  final Player player;

  /// 現在選択中の二重モノラルのチャンネル。null はステレオ (主＋副)。
  final DualMonoChannel? dualMonoChannel;

  /// 選択時のコールバック。呼び出し側 (コントロールより上位のウィジェット) で
  /// 状態に反映すること。
  final ValueChanged<AudioChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Tracks>(
      stream: player.stream.tracks,
      builder: (context, tracksSnapshot) {
        final tracks =
            tracksSnapshot.data?.audio ?? player.state.tracks.audio;
        // mpv が常に足す `auto` / `no` を除いた実トラック。
        final reserved = {AudioTrack.auto().id, AudioTrack.no().id};
        final realTracks =
            tracks.where((t) => !reserved.contains(t.id)).toList();
        return StreamBuilder<Track>(
          stream: player.stream.track,
          builder: (context, trackSnapshot) {
            final current =
                trackSnapshot.data?.audio ?? player.state.track.audio;
            return IconButton(
              icon: const Icon(Icons.audiotrack),
              color: Colors.white,
              tooltip: '音声切替',
              onPressed: () => _showAudioMenu(context, realTracks, current),
            );
          },
        );
      },
    );
  }

  /// 音声選択メニューを表示し、選択結果を [onSelected] で返す。
  Future<void> _showAudioMenu(
    BuildContext context,
    List<AudioTrack> tracks,
    AudioTrack current,
  ) async {
    final anchorBox = context.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.hasSize) return;
    if (overlayBox == null || !overlayBox.hasSize) return;

    final origin = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final items = <PopupMenuEntry<AudioChoice>>[];
    if (tracks.length > 1) {
      for (var i = 0; i < tracks.length; i++) {
        items.add(
          CheckedPopupMenuItem<AudioChoice>(
            value: AudioTrackChoice(tracks[i].id),
            checked: tracks[i].id == current.id,
            child: Text(
              audioTrackLabel(
                title: tracks[i].title,
                language: tracks[i].language,
                index: i + 1,
              ),
            ),
          ),
        );
      }
    } else {
      items.addAll([
        CheckedPopupMenuItem<AudioChoice>(
          value: const DualMonoChoice(null),
          checked: dualMonoChannel == null,
          child: const Text('ステレオ（主＋副）'),
        ),
        CheckedPopupMenuItem<AudioChoice>(
          value: const DualMonoChoice(DualMonoChannel.main),
          checked: dualMonoChannel == DualMonoChannel.main,
          child: Text(DualMonoChannel.main.label),
        ),
        CheckedPopupMenuItem<AudioChoice>(
          value: const DualMonoChoice(DualMonoChannel.sub),
          checked: dualMonoChannel == DualMonoChannel.sub,
          child: Text(DualMonoChannel.sub.label),
        ),
      ]);
    }

    final selected = await showMenu<AudioChoice>(
      context: context,
      // `PopupMenuButton` の既定位置指定に合わせる (ボタン直下・左右16px)。
      position: RelativeRect.fromLTRB(
        origin.dx + 16,
        origin.dy + anchorBox.size.height,
        overlayBox.size.width - origin.dx - anchorBox.size.width - 16,
        overlayBox.size.height - origin.dy - anchorBox.size.height,
      ),
      items: items,
    );
    if (selected == null) return;
    onSelected(selected);
  }
}

/// 弾幕表示のオン/オフ切替ボタン。ライブ視聴と録画再生で共有する。
///
/// 弾幕は映像の上に描くため、操作系のボタンに載せる。
class DanmakuToggleButton extends StatelessWidget {
  const DanmakuToggleButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        enabled ? Icons.subtitles : Icons.subtitles_off_outlined,
      ),
      color: Colors.white,
      tooltip: enabled ? '弾幕を非表示' : '弾幕を表示',
      onPressed: onPressed,
    );
  }
}
