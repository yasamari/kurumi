import 'package:freezed_annotation/freezed_annotation.dart';

part 'tv_program.freezed.dart';

/// バックエンド非依存の番組情報。
@freezed
abstract class TvProgram with _$TvProgram {
  const factory TvProgram({
    required int eventId,
    required String title,
    @Default('') String description,
    required DateTime startAt,
    required DateTime endAt,

    /// 表示用のジャンル名一覧 (例: `['ニュース／報道', 'スポーツ']`)。なければ空。
    @Default([]) List<String> genres,

    /// 番組詳細 (例: `{'出演者': '...'}`)。KonomiTV の `detail`、
    /// Mirakurun の `extended` を文字列化したもの。なければ空。
    @Default({}) Map<String, String> detail,
  }) = _TvProgram;
}
