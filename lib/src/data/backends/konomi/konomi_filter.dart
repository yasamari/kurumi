import '../../../domain/entities/channel.dart';
import '../../../domain/entities/channel_item.dart';
import '../../../domain/entities/channel_type.dart';
import '../../../domain/entities/tv_program.dart';
import 'konomi_dtos.dart';

/// `GET /api/channels` のレスポンスから表示用 [ChannelItem] を組み立てる純粋関数。
///
/// 仕様:
/// - `is_display` が false のチャンネルは除外する
/// - `program_present` が null (放送情報なし) のチャンネルは除外する
///   (Mirakurun側の「放送中のみ」方針に合わせる)
/// - 出力順はレスポンスの種別・配列順 (GR→BS→CS→CATV→SKY→BS4K) を維持する
List<ChannelItem> buildKonomiChannelItems({
  required KonomiChannelsResponse response,
  required String baseUrl,
}) {
  final items = <ChannelItem>[];
  for (final channel in response.allInOrder) {
    if (!channel.isDisplay) continue;
    final present = channel.programPresent;
    final following = channel.programFollowing;

    items.add(
      ChannelItem(
        channel: Channel(
          id: channel.displayChannelId,
          name: channel.name,
          channelType: channelTypeFromString(channel.type),
          channelNumber: channel.channelNumber ?? '',
          logoUrl: '$baseUrl/api/channels/${channel.displayChannelId}/logo',
        ),
        nowOnAir: present == null ? null : _toTvProgram(present),
        nextUp: following == null ? null : _toTvProgram(following),
      ),
    );
  }
  return items;
}

TvProgram _toTvProgram(KonomiProgramDto dto) {
  return TvProgram(
    eventId: dto.eventId,
    title: dto.title,
    description: dto.description,
    startAt: dto.startTime,
    endAt: dto.endTime,
  );
}
