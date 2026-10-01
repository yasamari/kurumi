import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/backends/konomi/konomi_video_stream.dart';

const _baseUrl = 'http://example.test:7000';

void main() {
  test('画質を正規化する', () {
    expect(normalizeKonomiVideoQuality('1080p'), '1080p');
    expect(normalizeKonomiVideoQuality('720p-hevc'), '720p-hevc');
    expect(normalizeKonomiVideoQuality('original'), 'original');
    expect(normalizeKonomiVideoQuality('4k'), '1080p');
    expect(normalizeKonomiVideoQuality(''), '1080p');
  });

  test('original画質かを判定する', () {
    expect(isOriginalKonomiVideoQuality('original'), isTrue);
    expect(isOriginalKonomiVideoQuality('1080p'), isFalse);
    expect(isOriginalKonomiVideoQuality('4k'), isFalse);
  });

  test('HLSプレイリストURLを組み立てる', () {
    final url = buildKonomiVideoHlsUrl(
      baseUrl: _baseUrl,
      videoId: 42,
      quality: '1080p',
      sessionId: 'abc123',
    );
    expect(
      url.toString(),
      '$_baseUrl/api/streams/video/42/1080p/playlist?session_id=abc123',
    );
  });

  test('末尾スラッシュ付きベースURLでも組み立てる', () {
    final url = buildKonomiVideoHlsUrl(
      baseUrl: '$_baseUrl/',
      videoId: 42,
      quality: '720p',
      sessionId: 'abc123',
    );
    expect(
      url.toString(),
      '$_baseUrl/api/streams/video/42/720p/playlist?session_id=abc123',
    );
  });

  test('ダウンロードURLを組み立てる', () {
    final url = buildKonomiVideoDownloadUrl(baseUrl: _baseUrl, videoId: 42);
    expect(url.toString(), '$_baseUrl/api/videos/42/download');
  });

  test('セッションIDは32桁hexで重ならない', () {
    final first = generateVideoSessionId();
    final second = generateVideoSessionId();
    expect(first, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(first, isNot(second));
  });
}
