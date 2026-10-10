import 'package:freezed_annotation/freezed_annotation.dart';

part 'video_thumbnail_tiles.freezed.dart';

/// シークバーでホバー位置のサムネイルを出すためのタイル並び画像。
///
/// KonomiTV は録画のサムネイルを等間隔に切り出し、1枚のWebPに
/// `column_count` 枚ずつ行方向に並べて `/api/videos/{id}/thumbnail/tiled`
/// から配信する。再生位置から求めた番号のタイルを切り出して表示する
/// (`seek_thumbnail.dart` の純関数)。
@freezed
abstract class VideoThumbnailTiles with _$VideoThumbnailTiles {
  const factory VideoThumbnailTiles({
    /// 並べた画像のURL (`/api/videos/{id}/thumbnail/tiled`)。
    required String url,

    /// 1枚のタイルの幅 (px)。
    required int tileWidth,

    /// 1枚のタイルの高さ (px)。
    required int tileHeight,

    /// 1行のタイル枚数。
    required int columnCount,

    /// タイルの総枚数。
    required int totalTiles,

    /// 隣り合うタイルの時刻差 (秒)。
    required double intervalSec,
  }) = _VideoThumbnailTiles;
}
