import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_channel_map.dart';
import 'package:kurumi/src/domain/entities/channel_type.dart';

void main() {
  // 地上波の NID は 0x7880〜0x7FEF の実値を使う (表内では 15 に束ねられている)。
  const terrestrialNetworkId = 0x7880;
  const bsNetworkId = 4;
  const bs4kNetworkId = 11;
  const csNetworkId = 7;
  // CATV の代表 NID。数値的には地上波の範囲 (0x7880〜0x7FEF) に含まれる。
  const catvNetworkId = 0x7CA0;

  String? resolve(ChannelType type, int serviceId, {int? networkId}) =>
      resolveJikkyoChannelId(
        channelType: type,
        networkId: networkId ?? terrestrialNetworkId,
        serviceId: serviceId,
      );

  group('地上波', () {
    test('network_id に関係なく service_id の一致で実況チャンネルになる', () {
      // 表: 0x0400 (1024) = NHK総合・東京 → jk1
      expect(resolve(const ChannelType.gr(), 0x0400), 'jk1');
    });

    test('1つ前の service_id があればフォールバックで一致する', () {
      // NHK総合2・東京 (0x0401) は表に無いが、1つ前の 0x0400 が jk1 に対応する。
      expect(resolve(const ChannelType.gr(), 0x0401), 'jk1');
    });

    test('2つ前の service_id があればフォールバックで一致する', () {
      expect(resolve(const ChannelType.gr(), 0x0402), 'jk1');
    });

    test('フォールバックは2つ前までで、3つ前へはしない', () {
      // 0x0403 から 0x0400 までは 3つ前の関係なので一致しない。
      expect(resolve(const ChannelType.gr(), 0x0403), isNull);
    });

    test('NID の下限・上限でも同じ結果になる', () {
      // 地上波の判定は NID ではなく種別で行うため、NID は影響しない。
      expect(resolve(const ChannelType.gr(), 0x0400, networkId: 0x7880), 'jk1');
      expect(resolve(const ChannelType.gr(), 0x0400, networkId: 0x7FEF), 'jk1');
    });
  });

  group('BS・BS4K', () {
    test('network_id と service_id の完全一致で決まる', () {
      // 表: (4, 141) = BS日テレ → jk141
      expect(
        resolve(const ChannelType.bs(), 141, networkId: bsNetworkId),
        'jk141',
      );
    });

    test('service_id が違えば一致しない', () {
      expect(
        resolve(const ChannelType.bs(), 999, networkId: bsNetworkId),
        isNull,
      );
    });

    test('BS4K は network_id 違いで同じ service_id でも別チャンネル', () {
      // (4, 101) は jk101 (NHK BS)、(11, 101) は jk103 (NHK BSプレミアム4K)。
      expect(
        resolve(const ChannelType.bs(), 101, networkId: bsNetworkId),
        'jk101',
      );
      expect(
        resolve(const ChannelType.bs4k(), 101, networkId: bs4kNetworkId),
        'jk103',
      );
    });

    test('CS の AT-X は jk333 になる', () {
      expect(
        resolve(const ChannelType.cs(), 333, networkId: csNetworkId),
        'jk333',
      );
    });

    test('jk263 は jk200 として解決する', () {
      // 表: (4, 263) は後方互換のため jk200 を指す。
      expect(
        resolve(const ChannelType.bs(), 263, networkId: bsNetworkId),
        'jk200',
      );
    });
  });

  group('CATV・SKY', () {
    test('CATV は NID が地上波の範囲内でも null になる', () {
      // CATV の NID 0x7CA0 は地上波範囲 0x7880〜0x7FEF に数値的に含まれるため、
      // 種別で判別しないと地上波として誤検出する。
      expect(
        resolve(const ChannelType.catv(), 0x0400, networkId: catvNetworkId),
        isNull,
      );
    });

    test('SKY も null になる', () {
      expect(
        resolve(const ChannelType.sky(), 0x2A00, networkId: 0x7AB5),
        isNull,
      );
    });

    test('種別不明でも null になる', () {
      expect(
        resolve(const ChannelType.unknown(), 0x0400, networkId: catvNetworkId),
        isNull,
      );
    });
  });

  group('実況非対応チャンネル', () {
    test('jikkyo_id が -1 のエントリは null になり、フォールバックも選ばない', () {
      // 実非対応の SID は null として保持され、sid-1 へフォールバックしない。
      // フォールバックすると別地域の SID にマッチして誤検出しうるため。
      expect(
        resolve(const ChannelType.cs(), 295, networkId: csNetworkId),
        isNull,
      );
      expect(
        resolve(const ChannelType.cs(), 294, networkId: csNetworkId),
        isNull,
      );
      expect(
        resolve(const ChannelType.cs(), 293, networkId: csNetworkId),
        isNull,
      );
    });
  });

  group('NX-Jikkyo に登録が無い ID', () {
    test('表にはあっても接続先が拒否する ID は null になる', () {
      // 表: (4, 256) = jk256、NX-Jikkyo は 1008 で拒否する。
      expect(
        resolve(const ChannelType.bs(), 256, networkId: bsNetworkId),
        isNull,
      );
      // (4, 202) = jk202 も同様に登録が無い。
      expect(
        resolve(const ChannelType.bs(), 202, networkId: bsNetworkId),
        isNull,
      );
    });

    test('isKnownJikkyoChannelId は登録済みの ID のみ真になる', () {
      expect(isKnownJikkyoChannelId('jk1'), isTrue);
      expect(isKnownJikkyoChannelId('jk256'), isFalse);
    });
  });

  group('同一キーの重複エントリ', () {
    // 上流表には同じ (network_id, service_id) を持つ行が4組ある。どれも jk ID が
    // 同一なので、対応表では1キーに畳んでいる。畳んでも解決結果が変わらないこと。
    test('地上波の重複も同上', () {
      // 15:56336 = 福岡の朝日放送・テレビ朝日 (KBC九州朝日放送 / KBCテレビ) → jk5
      expect(resolve(const ChannelType.gr(), 56336), 'jk5');
      // 15:56368 = 福岡のテレビ西日本 → jk8
      expect(resolve(const ChannelType.gr(), 56368), 'jk8');
    });

    test('BS の重複も同上', () {
      // 4:200 = BS10 / スターチャンネル1 → jk200、4:201 = → jk201
      expect(
        resolve(const ChannelType.bs(), 200, networkId: bsNetworkId),
        'jk200',
      );
      expect(
        resolve(const ChannelType.bs(), 201, networkId: bsNetworkId),
        'jk201',
      );
    });
  });
}
