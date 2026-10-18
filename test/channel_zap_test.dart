import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/domain/entities/channel.dart';
import 'package:kurumi/src/domain/entities/channel_item.dart';
import 'package:kurumi/src/domain/entities/channel_type.dart';
import 'package:kurumi/src/features/player/watch_screen.dart';

ChannelItem _item(String id, ChannelType type) => ChannelItem(
  channel: Channel(
    id: id,
    name: 'ch$id',
    channelType: type,
    networkId: 0,
    serviceId: int.parse(id),
  ),
  nowOnAir: null,
  nextUp: null,
);

void main() {
  group('同一チャンネル種別の ID 並び', () {
    final items = [
      _item('1', ChannelType.gr()),
      _item('2', ChannelType.gr()),
      _item('3', ChannelType.gr()),
      _item('10', ChannelType.bs()),
      _item('11', ChannelType.bs()),
      _item('20', ChannelType.catv()),
    ];

    test('種別ごとに表示順で取り出す', () {
      expect(channelIdsOfSameType(items, ChannelType.gr()), ['1', '2', '3']);
      expect(channelIdsOfSameType(items, ChannelType.bs()), ['10', '11']);
      expect(channelIdsOfSameType(items, ChannelType.catv()), ['20']);
    });

    test('該当する種別が無ければ空', () {
      expect(channelIdsOfSameType(items, ChannelType.sky()), isEmpty);
      expect(channelIdsOfSameType(const [], ChannelType.gr()), isEmpty);
    });
  });

  group('前/次チャンネルの行き先', () {
    const ids = ['1', '2', '3'];

    test('次のチャンネルは次の並びへ', () {
      expect(channelZapId(ids, '1', isNext: true), '2');
      expect(channelZapId(ids, '2', isNext: true), '3');
    });

    test('前のチャンネルは前の並びへ', () {
      expect(channelZapId(ids, '2', isNext: false), '1');
      expect(channelZapId(ids, '3', isNext: false), '2');
    });

    test('末尾では反対端に回り込む', () {
      expect(channelZapId(ids, '3', isNext: true), '1');
      expect(channelZapId(ids, '1', isNext: false), '3');
    });

    test('候補が1件以下なら切替しない', () {
      expect(channelZapId(const [], '1', isNext: true), isNull);
      expect(channelZapId(const ['1'], '1', isNext: true), isNull);
      expect(channelZapId(const ['1'], '1', isNext: false), isNull);
    });

    test('現在チャンネルが一覧に無ければ切替しない', () {
      expect(channelZapId(ids, '9', isNext: true), isNull);
      expect(channelZapId(ids, '9', isNext: false), isNull);
    });
  });
}
