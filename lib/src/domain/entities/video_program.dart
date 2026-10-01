import 'package:freezed_annotation/freezed_annotation.dart';

import 'channel.dart';
import 'recorded_file_info.dart';
import 'tv_program.dart';

part 'video_program.freezed.dart';

/// 録画番組 (KonomiTV ビデオ) の表示用モデル。
@freezed
abstract class VideoProgram with _$VideoProgram {
  const factory VideoProgram({
    /// 録画番組 ID (`/api/videos/{id}` の `video_id`)。
    required int id,

    /// 番組タイトル。
    required String title,

    /// シリーズ名。なければ null。
    String? seriesTitle,

    /// 話数表記 (例: `第85話`)。なければ null。
    String? episodeNumber,

    /// サブタイトル。なければ null。
    String? subtitle,

    /// 番組概要。
    @Default('') String description,

    /// 番組詳細 (例: `{'出演者': '...'}`)。なければ空。
    @Default({}) Map<String, String> detail,

    /// 放送開始・終了日時。
    required DateTime startAt,
    required DateTime endAt,

    /// 表示用のジャンル名一覧。なければ空。
    @Default([]) List<String> genres,

    /// 放送チャンネル。チャンネル不明の録画では null。
    Channel? channel,

    /// サムネイル画像のURL。
    required String thumbnailUrl,

    /// 録画ファイルの技術情報。取得できていない場合は null。
    RecordedFileInfo? recordedFile,
  }) = _VideoProgram;
}

/// [VideoProgram] から共有番組情報表示用の [TvProgram] へ変換する。
extension VideoProgramX on VideoProgram {
  TvProgram toTvProgram() {
    return TvProgram(
      eventId: id,
      title: title,
      description: description,
      startAt: startAt,
      endAt: endAt,
      genres: genres,
      detail: detail,
    );
  }
}
