import 'package:flutter_test/flutter_test.dart';

import 'package:kurumi/src/domain/entities/channel.dart';
import 'package:kurumi/src/domain/entities/channel_item.dart';
import 'package:kurumi/src/domain/entities/channel_type.dart';
import 'package:kurumi/src/domain/entities/tv_program.dart';
import 'package:kurumi/src/features/tv/tv_providers.dart';

const _hourMs = 3600 * 1000;

ChannelItem _item({required String id, int? presentEndMs, int? nextStartMs}) {
  TvProgram? program(int eventId, int startMs, int endMs) {
    return TvProgram(
      eventId: eventId,
      title: '番組$eventId',
      startAt: DateTime.fromMillisecondsSinceEpoch(startMs),
      endAt: DateTime.fromMillisecondsSinceEpoch(endMs),
    );
  }

  return ChannelItem(
    channel: Channel(
      id: id,
      name: id,
      channelType: const ChannelType.gr(),
      networkId: 1,
      serviceId: 1,
    ),
    nowOnAir: presentEndMs == null
        ? null
        : program(1, presentEndMs - _hourMs, presentEndMs),
    nextUp: nextStartMs == null
        ? null
        : program(2, nextStartMs, nextStartMs + _hourMs),
  );
}

void main() {
  // 2026-09-29 10:30 相当の固定時刻。
  final nowMs = DateTime(2026, 9, 29, 10, 30).millisecondsSinceEpoch;

  test('最も早い番組終了時刻を選ぶ', () {
    final tick = nextChannelListTickMs(
      items: [
        _item(id: 'a', presentEndMs: nowMs + 2 * _hourMs),
        _item(id: 'b', presentEndMs: nowMs + 30 * 60 * 1000),
      ],
      nowMs: nowMs,
    );
    expect(tick, nowMs + 30 * 60 * 1000);
  });

  test('次番組の開始が早ければそちらを選ぶ', () {
    final tick = nextChannelListTickMs(
      items: [
        _item(
          id: 'a',
          presentEndMs: nowMs + 2 * _hourMs,
          nextStartMs: nowMs + 10 * 60 * 1000,
        ),
      ],
      nowMs: nowMs,
    );
    expect(tick, nowMs + 10 * 60 * 1000);
  });

  test('過去の時刻は無視する', () {
    final tick = nextChannelListTickMs(
      items: [
        _item(
          id: 'a',
          presentEndMs: nowMs - _hourMs,
          nextStartMs: nowMs + _hourMs,
        ),
      ],
      nowMs: nowMs,
    );
    expect(tick, nowMs + _hourMs);
  });

  test('有効な境界がなければ60秒後', () {
    expect(
      nextChannelListTickMs(items: const [], nowMs: nowMs),
      nowMs + 60 * 1000,
    );
    expect(
      nextChannelListTickMs(
        items: [_item(id: 'a')],
        nowMs: nowMs,
      ),
      nowMs + 60 * 1000,
    );
  });
}
