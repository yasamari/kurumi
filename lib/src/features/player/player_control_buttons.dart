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

/// 字幕表示のオンオフ切替ボタン (ARIB字幕など)。ライブ視聴と録画再生で共有する。
///
/// 下部バーの設定ボタンの左に置く。
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

/// 標準コントロールの上部ボタンバーを組み立てる。
///
/// 並びは「戻る → タイトル」のみ。画質・弾幕・音声は下部バーの設定ボタン
/// ([PlayerSettingsButton]) にまとめる。AppBar は使わず標準コントロールの
/// 内側に載せる。
List<Widget> buildPlayerTopButtonBar({
  required String title,
  required String backFallbackPath,
}) {
  return <Widget>[
    PlayerBackButton(fallbackPath: backFallbackPath),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ];
}
