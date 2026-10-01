import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/tv_repository.dart';
import 'videos_providers.dart';
import 'widgets/video_detail_pane.dart';

/// 録画番組の詳細画面。狭幅時の `/videos/:id` プッシュ遷移先。
///
/// 中身は広幅2ペイン時と共有の [VideoDetailPane]。システムバック
/// (`pop`) でリストに戻る点が、Compose の `NavigableListDetailPaneScaffold`
/// における `PopUntilScaffoldValueChange` の振る舞いに相当する。
///
/// 開いた番組は [selectedVideoIdProvider] にも反映し、回転で広幅2ペインに
/// 変わったときに同じ番組が出るようにする。
class VideoDetailScreen extends ConsumerStatefulWidget {
  const VideoDetailScreen({super.key, required this.videoId});

  final int videoId;

  @override
  ConsumerState<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends ConsumerState<VideoDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectedVideoIdProvider.notifier).select(widget.videoId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(videoDetailProvider(widget.videoId));

    return Scaffold(
      appBar: AppBar(title: const Text('番組詳細')),
      body: SafeArea(
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            if (error is BackendUnconfiguredException) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('サーバーが設定されていません'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => context.go('/settings'),
                      child: const Text('設定を開く'),
                    ),
                  ],
                ),
              );
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 64),
                    const SizedBox(height: 16),
                    const Text('取得に失敗しました'),
                    const SizedBox(height: 8),
                    Text('$error', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(
                        videoDetailProvider(widget.videoId),
                      ),
                      child: const Text('再試行'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (video) => VideoDetailPane(video: video),
        ),
      ),
    );
  }
}
