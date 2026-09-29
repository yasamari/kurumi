import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/backends/konomi/konomi_live.dart';
import 'package:kurumi/src/data/backends/mirakurun/mirakurun_live.dart';

void main() {
  group('MirakurunライブURL組み立て', () {
    test('サービスIDとdecode=1を付与する', () {
      final url = buildMirakurunLiveStreamUrl(
        baseUrl: 'http://192.168.1.2:40772',
        serviceId: '32736',
      );
      expect(
        url.toString(),
        'http://192.168.1.2:40772/api/services/32736/stream?decode=1',
      );
    });

    test('ベースURL末尾のスラッシュを吸収する', () {
      final url = buildMirakurunLiveStreamUrl(
        baseUrl: 'http://192.168.1.2:40772/',
        serviceId: '32736',
      );
      expect(
        url.toString(),
        'http://192.168.1.2:40772/api/services/32736/stream?decode=1',
      );
    });
  });

  group('KonomiTVライブURL組み立て', () {
    test('チャンネルIDと画質を埋め込む', () {
      final url = buildKonomiLiveStreamUrl(
        baseUrl: 'http://192.168.1.2:7000',
        displayChannelId: 'gr011',
        quality: '720p',
      );
      expect(
        url.toString(),
        'http://192.168.1.2:7000/api/streams/live/gr011/720p/mpegts',
      );
    });

    test('既定画質はoriginalである', () {
      expect(defaultKonomiQuality, 'original');
      final url = buildKonomiLiveStreamUrl(
        baseUrl: 'http://192.168.1.2:7000',
        displayChannelId: 'gr011',
        quality: defaultKonomiQuality,
      );
      expect(
        url.toString(),
        'http://192.168.1.2:7000/api/streams/live/gr011/original/mpegts',
      );
    });

    test('全17画質が定義されている', () {
      expect(konomiLiveQualities.length, 17);
      expect(konomiLiveQualities.first, 'original');
    });

    test('不正な画質はoriginalに正規化される', () {
      expect(normalizeKonomiQuality('存在しない画質'), 'original');
      final url = buildKonomiLiveStreamUrl(
        baseUrl: 'http://192.168.1.2:7000',
        displayChannelId: 'gr011',
        quality: '存在しない画質',
      );
      expect(
        url.toString(),
        'http://192.168.1.2:7000/api/streams/live/gr011/original/mpegts',
      );
    });

    test('ベースURL末尾のスラッシュを吸収する', () {
      final url = buildKonomiLiveStreamUrl(
        baseUrl: 'http://192.168.1.2:7000/',
        displayChannelId: 'bs101',
        quality: 'original',
      );
      expect(
        url.toString(),
        'http://192.168.1.2:7000/api/streams/live/bs101/original/mpegts',
      );
    });
  });
}
