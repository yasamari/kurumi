import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/settings/app_settings.dart';
import '../../data/backends/konomi/konomi_live.dart';
import '../../domain/entities/backend_type.dart';
import '../../domain/repositories/tv_repository.dart';
import '../tv/tv_providers.dart';
import 'mpv_options.dart';
import 'watch_providers.dart';

/// ライブ視聴画面。全画面プレイヤー遷移先 (`/watch/:channelId`)。
///
/// ナビゲーション (NavigationBar/Rail/Drawer) は表示しない。この画面は
/// StatefulShellRoute の外側 (`rootNavigatorKey` 上) に積まれるため、
/// シェル側のナビゲーションが隠れる。
///
/// 再生UIはmedia_kit標準 (`AdaptiveVideoControls`) を使う。戻るボタン・番組名・
/// 画質切替ボタンはAppBarではなく、標準コントロールの上部ボタンバーに載せる。
/// ライブのためシークバー・シーク系ジェスチャは無効化する。
class WatchScreen extends ConsumerWidget {
  const WatchScreen({super.key, required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(nowOnAirChannelsProvider);
    final settings = ref.watch(appSettingsProvider).value;
    final backendType = settings?.backendType ?? BackendType.mirakurun;

    return channels.when(
      loading: () => const _PlaceholderScaffold(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) {
        if (error is BackendUnconfiguredException) {
          return const _PlaceholderScaffold(
            child: Center(child: Text('サーバーが設定されていません')),
          );
        }
        return _PlaceholderScaffold(
          child: _RetryError(
            message: '$error',
            onRetry: () => ref.invalidate(nowOnAirChannelsProvider),
          ),
        );
      },
      data: (items) {
        final item =
            items.where((e) => e.channel.id == channelId).firstOrNull;
        if (item == null) {
          return _PlaceholderScaffold(
            child: _RetryError(
              message: 'チャンネルが見つかりません',
              onRetry: () => ref.invalidate(nowOnAirChannelsProvider),
            ),
          );
        }
        final channel = item.channel;
        final title = channel.channelNumber.isEmpty
            ? channel.name
            : '${channel.channelNumber} ${channel.name}';
        return _WatchBody(
          channelId: channelId,
          title: title,
          showQualityMenu: backendType == BackendType.konomiTv,
        );
      },
    );
  }
}

/// まだプレイヤーを描画していない状態 (読み込み中・エラー) の土台。
/// media_kitの標準コントロールが存在しないため、戻るボタンは自前で置く。
class _PlaceholderScaffold extends StatelessWidget {
  const _PlaceholderScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          const Positioned(
            left: 4,
            top: 4,
            child: SafeArea(child: _BackButton()),
          ),
        ],
      ),
    );
  }
}

/// テレビ画面へ戻るボタン。
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/tv');
        }
      },
      icon: const Icon(Icons.arrow_back),
      color: Colors.white,
      tooltip: '戻る',
    );
  }
}

/// 画質切替ボタン (KonomiTVのみ表示)。全17画質から選択できる。
///
/// `PopupMenuButton` は使わない。media_kit のコントロールは自動非表示になる
/// と `mount=false` としてツリーから取り除かれるため、メニュー選択時点で
/// このウィジェットが破棄されていることがある。その場合 Flutter 内部の
/// `if (!mounted) return;` により `onSelected` が呼ばれず、画質が切り替わらない。
/// そのため `showMenu` を直接呼び、`ProviderContainer` 経由で反映する。
class _QualityMenuButton extends ConsumerWidget {
  const _QualityMenuButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quality = ref.watch(watchQualityProvider);
    return IconButton(
      icon: const Icon(Icons.high_quality_outlined),
      color: Colors.white,
      tooltip: '画質切替',
      onPressed: () => _showQualityMenu(context, quality),
    );
  }
}

/// 画質選択メニューを表示し、選択結果を反映する。
Future<void> _showQualityMenu(BuildContext context, String current) async {
  // コントロールが破棄された後でも状態を反映できるよう、コンテナを先に控える。
  final container = ProviderScope.containerOf(context, listen: false);
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
      for (final q in konomiLiveQualities)
        CheckedPopupMenuItem<String>(
          value: q,
          checked: q == current,
          child: Text(q),
        ),
    ],
  );
  if (selected == null) return;
  container.read(watchQualityProvider.notifier).setQuality(selected);
}

class _WatchBody extends ConsumerWidget {
  const _WatchBody({
    required this.channelId,
    required this.title,
    required this.showQualityMenu,
  });

  final String channelId;

  /// 上部ボタンバーに表示する番組名 (チャンネル番号 + 局名)。
  final String title;

  /// KonomiTVのときだけ画質切替を出す (Mirakurunは `decode=1` 固定のため)。
  final bool showQualityMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(liveStreamProvider(channelId));
    return Scaffold(
      backgroundColor: Colors.black,
      body: stream.when(
        loading: () => const _PlaceholderScaffold(
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) {
          final message = error is ChannelNotFoundException
              ? 'チャンネルが見つかりません'
              : 'ストリームの取得に失敗しました\n$error';
          return _PlaceholderScaffold(
            child: _RetryError(
              message: message,
              onRetry: () => ref.invalidate(liveStreamProvider(channelId)),
            ),
          );
        },
        data: (live) => _LivePlayer(
          // URLが変わったらPlayerを作り直す (画質切替対応)。
          key: ValueKey(live.url.toString()),
          url: live.url,
          title: title,
          showQualityMenu: showQualityMenu,
        ),
      ),
    );
  }
}

/// media_kitのPlayer/Controllerを所有するウィジェット。
///
/// 画面離脱・画質切替時に `dispose`/`open` し直すことでチューナーを解放する。
class _LivePlayer extends StatefulWidget {
  const _LivePlayer({
    super.key,
    required this.url,
    required this.title,
    required this.showQualityMenu,
  });

  final Uri url;
  final String title;
  final bool showQualityMenu;

  @override
  State<_LivePlayer> createState() => _LivePlayerState();
}

class _LivePlayerState extends State<_LivePlayer> {
  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<String>? _errorSub;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _errorSub = _player.stream.error.listen((message) {
      if (message.isNotEmpty && mounted) {
        setState(() => _errorMessage = message);
      }
    });
    _initialize();
  }

  /// mpvオプションを適用してから映像を開く。
  ///
  /// オプションはデコーダ生成時に読まれるため、必ず `open` より前に渡す。
  Future<void> _initialize() async {
    await applyLiveMpvOptions(_player);
    if (!mounted) return;
    await _open();
  }

  Future<void> _open() async {
    if (mounted) {
      setState(() => _errorMessage = null);
    }
    await _player.open(Media(widget.url.toString()));
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AppBarの代わりに、標準コントロールの上部ボタンバーへ載せる。
    final topButtonBar = <Widget>[
      const _BackButton(),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (widget.showQualityMenu) const _QualityMenuButton(),
    ];

    // ライブのためシークバー・シーク系操作を無効化する。
    final liveMaterialTheme = MaterialVideoControlsThemeData(
      displaySeekBar: false,
      seekGesture: false,
      seekOnDoubleTap: false,
      automaticallyImplySkipNextButton: false,
      automaticallyImplySkipPreviousButton: false,
      // 画面を開いた直後は操作ボタン (戻るボタン等) を表示しておく。
      visibleOnMount: true,
      // 既定3秒だと画質メニュー (全17件) を操作する前に消えてしまうため、
      // 長く表示し続ける。
      controlsHoverDuration: const Duration(seconds: 15),
      topButtonBar: topButtonBar,
    );
    final liveDesktopTheme = MaterialDesktopVideoControlsThemeData(
      displaySeekBar: false,
      automaticallyImplySkipNextButton: false,
      automaticallyImplySkipPreviousButton: false,
      visibleOnMount: true,
      controlsHoverDuration: const Duration(seconds: 15),
      topButtonBar: topButtonBar,
    );
    return Stack(
      children: [
        MaterialVideoControlsTheme(
          normal: liveMaterialTheme,
          fullscreen: liveMaterialTheme,
          child: MaterialDesktopVideoControlsTheme(
            normal: liveDesktopTheme,
            fullscreen: liveDesktopTheme,
            // media_kit標準UI。平台で自動切替される。
            child: Video(
              controller: _controller,
              controls: AdaptiveVideoControls,
            ),
          ),
        ),
        if (_errorMessage != null)
          Positioned.fill(
            // 上部のコントロール (戻るボタン等) を隠さないよう上端だけ空ける。
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
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '再生に失敗しました',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _open,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RetryError extends StatelessWidget {
  const _RetryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
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
  }
}
