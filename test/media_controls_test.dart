import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/core/media/media_control_target.dart';
import 'package:kurumi/src/core/media/now_playing_item.dart';

/// テスト用の委譲先。呼び出しを記録するだけ。
class _FakeTarget implements MediaControlTarget {
  int playCount = 0;
  int pauseCount = 0;
  int zapNextCount = 0;

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> zapToNext() async {
    zapNextCount++;
  }

  @override
  Future<void> zapToPrevious() async {}

  @override
  bool get supportsSeek => false;

  @override
  bool get supportsZap => true;
}

void main() {
  group('liveMediaItem', () {
    test('番組名があるときは番組をタイトル・チャンネルをアーティストにする', () {
      final item = liveMediaItem(
        channelId: '1',
        channelTitle: '011 NHK総合',
        programTitle: 'ニュース',
        artUri: Uri.parse('http://server/logo.png'),
      );
      expect(item.id, 'live:1');
      expect(item.title, 'ニュース');
      expect(item.artist, '011 NHK総合');
      expect(item.artUri.toString(), 'http://server/logo.png');
      expect(item.duration, isNull);
    });

    test('EIT未受信時はチャンネル名をタイトルにする', () {
      final item = liveMediaItem(
        channelId: '1',
        channelTitle: '011 NHK総合',
      );
      expect(item.title, '011 NHK総合');
      expect(item.artist, isNull);
      expect(item.artUri, isNull);
    });
  });

  group('videoMediaItem', () {
    test('番組名・チャンネル名・サムネイル・尺を載せる', () {
      final item = videoMediaItem(
        videoId: 42,
        title: 'ドラマ 第1話',
        channelName: 'NHK総合',
        artUri: Uri.parse('http://server/api/videos/42/thumbnail'),
        duration: const Duration(hours: 1),
      );
      expect(item.id, 'video:42');
      expect(item.title, 'ドラマ 第1話');
      expect(item.artist, 'NHK総合');
      expect(item.duration, const Duration(hours: 1));
    });

    test('尺が未確定でも組み立てられる', () {
      final item = videoMediaItem(videoId: 42, title: 'ドラマ');
      expect(item.duration, isNull);
      expect(item.artist, isNull);
    });
  });

  group('artUriOf', () {
    test('null・空文字はnull', () {
      expect(artUriOf(null), isNull);
      expect(artUriOf(''), isNull);
    });

    test('httpのURLは通す', () {
      expect(
        artUriOf('http://server/logo.png').toString(),
        'http://server/logo.png',
      );
    });

    test('スキーム無し・不正値は落とす', () {
      expect(artUriOf('not a url %%'), isNull);
      expect(artUriOf('/local/path.png'), isNull);
    });
  });

  group('MediaControls', () {
    test('attachした委譲先をtargetで読める', () {
      final controls = MediaControls.instance;
      final owner = Object();
      final target = _FakeTarget();
      controls.attach(owner: owner, target: target);
      expect(controls.target, same(target));
      expect(controls.detach(owner: Object()), isFalse);
      expect(controls.target, same(target));
      expect(controls.detach(owner: owner), isTrue);
      expect(controls.target, isNull);
    });

    test('別 owner の detach は新しい登録を壊さない', () {
      final controls = MediaControls.instance;
      final oldOwner = Object();
      final newOwner = Object();
      final oldTarget = _FakeTarget();
      final newTarget = _FakeTarget();
      controls.attach(owner: oldOwner, target: oldTarget);
      // チャンネル切替: 新画面の登録後に旧画面の解除が走る順序。
      controls.attach(owner: newOwner, target: newTarget);
      expect(controls.detach(owner: oldOwner), isFalse);
      expect(controls.target, same(newTarget));
      expect(controls.detach(owner: newOwner), isTrue);
      expect(controls.target, isNull);
    });
  });
}
