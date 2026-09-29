import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/domain/entities/channel_type.dart';

void main() {
  test('種別タブが正規順に並ぶ', () {
    expect(
      channelTypesInOrder([
        const ChannelType.unknown(),
        const ChannelType.bs(),
        const ChannelType.gr(),
        const ChannelType.gr(),
        const ChannelType.cs(),
      ]),
      [
        const ChannelType.gr(),
        const ChannelType.bs(),
        const ChannelType.cs(),
        const ChannelType.unknown(),
      ],
    );
  });

  test('種別ラベルが表示名になる', () {
    expect(const ChannelType.gr().label, '地デジ');
    expect(const ChannelType.bs4k().label, 'BS4K');
    expect(const ChannelType.unknown().label, 'その他');
  });
}
