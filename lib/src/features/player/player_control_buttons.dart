import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';

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
