import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/features/player/player_error.dart';

void main() {
  test('再生中で映像または音声があれば回復済みとする', () {
    expect(
      isPlayerRecovered(isPlaying: true, hasVideo: true, hasAudio: true),
      isTrue,
    );
    expect(
      isPlayerRecovered(isPlaying: true, hasVideo: true, hasAudio: false),
      isTrue,
    );
    expect(
      isPlayerRecovered(isPlaying: true, hasVideo: false, hasAudio: true),
      isTrue,
    );
  });

  test('停止中やパラメータ未受信は未回復とする', () {
    expect(
      isPlayerRecovered(isPlaying: false, hasVideo: true, hasAudio: true),
      isFalse,
    );
    expect(
      isPlayerRecovered(isPlaying: true, hasVideo: false, hasAudio: false),
      isFalse,
    );
    expect(
      isPlayerRecovered(isPlaying: false, hasVideo: false, hasAudio: false),
      isFalse,
    );
  });

  test('有効な映像サイズを判定する', () {
    expect(hasValidVideoSize(dw: 1920, dh: 1080), isTrue);
    expect(hasValidVideoSize(w: 1440, h: 1080), isTrue);
    // 放送開始直後の無効なフレーム (0x0) は映像なしとみなす
    expect(hasValidVideoSize(dw: 0, dh: 0), isFalse);
    expect(hasValidVideoSize(), isFalse);
  });

  test('有効な音声形式を判定する', () {
    expect(hasValidAudioFormat(sampleRate: 48000, channelCount: 2), isTrue);
    expect(hasValidAudioFormat(sampleRate: 48000), isTrue);
    expect(hasValidAudioFormat(), isFalse);
  });

  group('映像の表示アスペクト比', () {
    test('mpv の aspect を最優先する', () {
      // 最も正確なので、これを最優先する。
      expect(videoDisplayAspectOf(aspect: 16 / 9, w: 1440, h: 1080), 16 / 9);
    });

    test('1440x1080 を 16:9 に引き伸ばした放送を正しく扱う', () {
      // 日本語デジタル放送に多いケース。符号化は 4:3、表示は 16:9。
      // ここを w/h で判定すると 1.333 になり、矩形がズレて弾幕が黒帯に出る。
      final aspect = videoDisplayAspectOf(
        aspect: 16 / 9,
        w: 1440,
        h: 1080,
        dw: 1920,
        dh: 1080,
      );
      expect(aspect, closeTo(16 / 9, 0.0001));
      expect(aspect, isNot(closeTo(1440 / 1080, 0.0001)));
    });

    test('aspect が無いときは補正済みの dw/dh を使う', () {
      expect(
        videoDisplayAspectOf(w: 1440, h: 1080, dw: 1920, dh: 1080),
        closeTo(16 / 9, 0.0001),
      );
    });

    test('dw/dh も無いときは符号化サイズ w/h にフォールバックする', () {
      // // PAR の情報が無いストリームはそのまま符号化サイズの比になる。
      expect(videoDisplayAspectOf(w: 1920, h: 1080), closeTo(16 / 9, 0.0001));
      expect(videoDisplayAspectOf(w: 720, h: 576), closeTo(720 / 576, 0.0001));
    });

    test('有効な値が揃っていなければ null を返す', () {
      // 弾幕はアスペクト比が確定するまで描画しない。
      expect(videoDisplayAspectOf(), isNull);
      expect(videoDisplayAspectOf(aspect: 0), isNull);
      expect(videoDisplayAspectOf(aspect: double.nan), isNull);
      expect(videoDisplayAspectOf(aspect: double.infinity), isNull);
      expect(videoDisplayAspectOf(w: 1920, h: 0), isNull);
      expect(videoDisplayAspectOf(dw: 0, dh: 0, w: 0, h: 0), isNull);
    });
  });
}
