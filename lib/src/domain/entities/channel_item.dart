import 'package:freezed_annotation/freezed_annotation.dart';

import 'channel.dart';
import 'tv_program.dart';

part 'channel_item.freezed.dart';

/// チャンネル + 放送中番組 + 次番組の表示用モデル。
@freezed
abstract class ChannelItem with _$ChannelItem {
  const factory ChannelItem({
    required Channel channel,
    required TvProgram? nowOnAir,
    required TvProgram? nextUp,
  }) = _ChannelItem;
}
