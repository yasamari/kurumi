import 'package:flutter/material.dart';

import 'player_control_buttons.dart';

/// プレイヤー画面の土台。黒地に子を重ね、戻るボタンを左上に出す。
///
/// まだプレイヤーを描画していない状態 (読み込み中・エラー) の土台に使う。
/// media_kit の標準コントロールが存在しないため、戻るボタンは自前で置く。
class PlayerPlaceholderScaffold extends StatelessWidget {
  const PlayerPlaceholderScaffold({
    super.key,
    required this.child,
    this.backFallbackPath = '/tv',
  });

  final Widget child;

  /// 戻る遷移先が無いときのフォールバックパス。
  final String backFallbackPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 4,
            top: 4,
            child: SafeArea(
              child: PlayerBackButton(fallbackPath: backFallbackPath),
            ),
          ),
        ],
      ),
    );
  }
}

/// 映像スロット (映像と情報パネルを並べた矩形側) の状態表示。戻るボタンを
/// 左上に出す。
///
/// 映像が無い場所で読み込み表示やエラー表示を出すときの土台。[PlayerPlaceholderScaffold]
/// から `Scaffold` だけが違うので、こちらを使う。
class PlayerStatusOverlay extends StatelessWidget {
  const PlayerStatusOverlay({
    super.key,
    this.backFallbackPath = '/tv',
    required this.child,
  });

  /// 中央に置く状態表示。
  final Widget child;

  /// 戻る遷移先が無いときのフォールバックパス。
  final String backFallbackPath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: 4,
          top: 4,
          child: SafeArea(
            child: PlayerBackButton(fallbackPath: backFallbackPath),
          ),
        ),
      ],
    );
  }
}

/// 読み込み中表示。
class PlayerLoadingView extends StatelessWidget {
  const PlayerLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlayerStatusOverlay(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 取得失敗の表示。エラー内容と再試行を出す。
///
/// まだプレイヤーを描画していない状態 ([PlayerPlaceholderScaffold] 側) と、
/// セッション開設に失敗した映像スロット側 ([PlayerStatusOverlay] 側) の両方で
/// 使う。
class PlayerRetryView extends StatelessWidget {
  const PlayerRetryView({
    super.key,
    required this.message,
    required this.onRetry,
    this.backFallbackPath,
  });

  /// エラー内容。
  final String message;

  /// 再試行時のコールバック。
  final VoidCallback onRetry;

  /// 戻る遷移先が無いときのフォールバックパス。null なら重ねない。
  final String? backFallbackPath;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            const Text(
              '取得に失敗しました',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('再試行')),
          ],
        ),
      ),
    );
    final backFallback = backFallbackPath;
    if (backFallback == null) return content;
    return PlayerStatusOverlay(backFallbackPath: backFallback, child: content);
  }
}

/// 再生失敗のオーバーレイ。映像の上に被せてエラー内容と再試行を出す。
///
/// 上部のコントロール (戻るボタン等) を隠さないよう上端だけ空ける。
class PlayerErrorOverlay extends StatelessWidget {
  const PlayerErrorOverlay({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// mpv が返したエラー内容。
  final String message;

  /// 再試行時のコールバック。
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 64),
                const SizedBox(height: 16),
                const Text(
                  '再生に失敗しました',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('再試行')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
