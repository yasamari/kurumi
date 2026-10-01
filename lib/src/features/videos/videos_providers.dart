import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/backends/konomi/konomi_video_stream.dart';
import '../../domain/entities/video_program.dart';
import '../../domain/providers/backend_provider.dart';
import '../../domain/repositories/video_repository.dart';

part 'videos_providers.g.dart';

/// ビデオ画面の検索キーワード。永続化しない。
///
/// 入力のたびに直接書き換えず、呼び出し側がデバウンスしてから [set] する。
/// 変更すると [videosListProvider] が1ページ目から取り直す。
@Riverpod(keepAlive: true)
class VideosQuery extends _$VideosQuery {
  @override
  String build() => '';

  /// 検索キーワードを変える。同じ値は無視する。
  void set(String value) {
    if (state == value) return;
    state = value;
  }
}

/// ビデオ画面の並び順。永続化しない。既定は新しい順。
@Riverpod(keepAlive: true)
class VideosOrder extends _$VideosOrder {
  @override
  VideoSortOrder build() => VideoSortOrder.newest;

  /// 並び順を変える。同じ値は無視する。
  void set(VideoSortOrder order) {
    if (state == order) return;
    state = order;
  }
}

/// ビデオ画面で選択中の録画番組 ID。永続化しない。
///
/// Compose の `ThreePaneScaffoldNavigator` の `contentKey` に相当する。
/// 広幅2ペイン時の詳細表示と狭幅プッシュ遷移 (`/videos/:id`) の両方で使い、
/// 回転・再訪でも選択を保つため keepAlive にする。
@Riverpod(keepAlive: true)
class SelectedVideoId extends _$SelectedVideoId {
  @override
  int? build() => null;

  /// 選択を変える。同じ値は無視する。
  void select(int? id) {
    if (state == id) return;
    state = id;
  }
}

/// 録画番組一覧の読み込み状態 (ページ累積分)。
class VideosListState {
  const VideosListState({
    required this.items,
    required this.total,
    required this.page,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  /// これまでに読み込んだ番組 (サーバーの返却順を維持)。
  final List<VideoProgram> items;

  /// 条件に一致する番組の総数。
  final int total;

  /// 読み込み済みの最終ページ番号 (1始まり)。
  final int page;

  /// 未読のページが残っているかどうか。
  final bool hasMore;

  /// 追加ページの読み込み中かどうか。下端インジケーター表示に使う。
  final bool isLoadingMore;

  VideosListState copyWith({
    List<VideoProgram>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return VideosListState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// 録画番組一覧。検索・並び順の変更で1ページ目から取り直す。
@Riverpod(keepAlive: true)
class VideosList extends _$VideosList {
  @override
  Future<VideosListState> build() async {
    final query = ref.watch(videosQueryProvider);
    final order = ref.watch(videosOrderProvider);
    final repository = ref.watch(videoRepositoryProvider);
    final page = await repository.listVideos(
      query: query,
      order: order,
      page: 1,
    );
    return VideosListState(
      items: page.items,
      total: page.total,
      page: 1,
      hasMore: page.items.length < page.total,
    );
  }

  /// 次ページを読み込んで末尾に足す。読み込み中・残りなし・未読み込み時は
  /// 何もしない。失敗時は読み込み中表示だけ戻し、一覧は保つ。
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final repository = ref.read(videoRepositoryProvider);
      final page = await repository.listVideos(
        query: ref.read(videosQueryProvider),
        order: ref.read(videosOrderProvider),
        page: current.page + 1,
      );
      final items = [...current.items, ...page.items];
      state = AsyncData(
        VideosListState(
          items: items,
          total: page.total,
          page: current.page + 1,
          hasMore: items.length < page.total,
        ),
      );
    } catch (_) {
      state = AsyncData(current);
    }
  }
}

/// 録画番組1件の詳細。一覧キャッシュにあればそれを使い、なければ取得する。
@riverpod
Future<VideoProgram> videoDetail(Ref ref, int videoId) async {
  final cached = ref
      .watch(videosListProvider)
      .value
      ?.items
      .where((item) => item.id == videoId)
      .firstOrNull;
  if (cached != null) return cached;
  final repository = ref.watch(videoRepositoryProvider);
  return repository.getVideo(videoId);
}

/// 録画再生中の画質。永続化しない。既定は `1080p`。
///
/// HLSでは `original` を選べないため、選択時はダウンロード再生になる。
/// 再生画面を離れても保持する (keepAlive)。画質切替でプレイヤーを作り直す
/// ときに初期値に戻らないようにするため。
@Riverpod(keepAlive: true)
class VideoPlayQuality extends _$VideoPlayQuality {
  @override
  String build() => defaultKonomiVideoQuality;

  /// 画質を切り替える。不正値は `1080p` に正規化される。
  void setQuality(String quality) {
    final normalized = normalizeKonomiVideoQuality(quality);
    if (state == normalized) return;
    state = normalized;
  }
}

/// 録画再生画面の情報タブ。永続化しない。0=番組情報、1=コメント。
///
/// 再生画面の `Row` / `Column` 切り替えの内側にあるため、選択を保つには
/// この keepAlive provider が持つ必要がある (ライブの
/// `watchInfoTabProvider` と同様)。
@Riverpod(keepAlive: true)
class VideoInfoTab extends _$VideoInfoTab {
  @override
  int build() => 0;

  /// タブを切り替える。範囲外の値は無視する。
  void select(int index) {
    if (index < 0 || index > 1 || state == index) return;
    state = index;
  }
}
