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
  }) = _TvProgram;
}
