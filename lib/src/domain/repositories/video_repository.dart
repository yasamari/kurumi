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

/// 録画番組の再生ストリーム情報。
class VideoStreamInfo {
  const VideoStreamInfo({required this.url, required this.isHls});

  /// 再生URL。HLS時はプレイリスト、`original` 時はダウンロードURL。
  final Uri url;

  /// HLSプレイリストかどうか。真のとき視聴中の keep-alive が必要。
  final bool isHls;
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

  /// 再生ストリーム情報を返す。
  ///
  /// [quality] は `original` (ダウンロード再生) かHLS画質名。不正値は
  /// 既定 (`1080p`) に正規化される。[sessionId] はHLS用のセッションID
  /// (クライアント生成)。未設定時は [BackendUnconfiguredException]。
  VideoStreamInfo getVideoStream({
    required int videoId,
    required String quality,
    required String sessionId,
  });

  /// HLS視聴セッションを維持する。再生を続けている間、定期的に呼ぶ。
  ///
  /// 呼ばれなくなるとサーバーがセグメント生成を止める。`original`
  /// (ダウンロード再生) では不要。未設定時は [BackendUnconfiguredException]。
  Future<void> keepVideoStreamAlive({
    required int videoId,
    required String quality,
    required String sessionId,
  });
}
