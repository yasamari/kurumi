import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_stream.freezed.dart';

/// ライブ視聴用のストリーム情報。バックエンド非依存。
@freezed
abstract class LiveStream with _$LiveStream {
  const factory LiveStream({
    /// media_kit で直接開けるストリームURL。
    required Uri url,

    /// UI表示用の画質ラベル (例: `original`)。Mirakurunでは空文字。
    @Default('') String qualityLabel,
  }) = _LiveStream;
}
