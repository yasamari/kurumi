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

    /// MPEG-TS の network_id。Mirakurun の `networkId` /
    /// KonomiTV の `network_id` をそのまま保持する。
    ///
    /// バックエンドに依存しない ID で、ニコニコ実況チャンネル
    /// (`jk1` 等) への変換キーとして使う。
    required int networkId,

    /// MPEG-TS の service_id。Mirakurun の `serviceId` /
    /// KonomiTV の `service_id` をそのまま保持する。
    required int serviceId,

    /// ヘッダー表示用のチャンネル番号 (例: `011`)。なければ空文字。
    @Default('') String channelNumber,

    /// ロゴ画像のURL。なければ null。
    String? logoUrl,
  }) = _Channel;
}
