import 'package:freezed_annotation/freezed_annotation.dart';

import 'channel_type.dart';

part 'channel.freezed.dart';

/// バックエンド非依存のチャンネル情報。
@freezed
abstract class Channel with _$Channel {
  const factory Channel({
    required String id,
    required String name,
    required ChannelType channelType,

    /// ヘッダー表示用のチャンネル番号 (例: `011`)。なければ空文字。
    @Default('') String channelNumber,

    /// ロゴ画像のURL。なければ null。
    String? logoUrl,
  }) = _Channel;
}
