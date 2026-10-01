import '../entities/video_program.dart';

/// 録画番組の並び順。
enum VideoSortOrder {
  /// 新しい順 (`order=desc`)。
  newest,

  /// 古い順 (`order=asc`)。
  oldest;

  /// KonomiTV API の `order` パラメーター値。
  String get queryParam => switch (this) {
        VideoSortOrder.newest => 'desc',
        VideoSortOrder.oldest => 'asc',
      };

  /// ソートメニュー表示用のラベル。
  String get label => switch (this) {
        VideoSortOrder.newest => '新しい順',
        VideoSortOrder.oldest => '古い順',
      };
}

/// 録画番組一覧の1ページ分。
class VideoPage {
  const VideoPage({required this.items, required this.total});

  /// このページの番組一覧。
  final List<VideoProgram> items;

  /// 条件に一致する番組の総数。
  final int total;
}

/// バックエンド非依存の録画番組 (ビデオ) 操作インターフェース。
abstract class VideoRepository {
  /// 録画番組一覧を30件ずつ返す。
  ///
  /// [query] が空でないときはキーワード検索になる。[page] は1始まり。
  /// 未設定時は [BackendUnconfiguredException]。
  Future<VideoPage> listVideos({
    String query = '',
    VideoSortOrder order = VideoSortOrder.newest,
    int page = 1,
  });

  /// 録画番組1件を返す。未設定時は [BackendUnconfiguredException]。
  Future<VideoProgram> getVideo(int id);
}
