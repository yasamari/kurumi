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
}
