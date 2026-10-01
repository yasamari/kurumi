import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/core/utils/media_format.dart';

void main() {
  test('ファイルサイズを人間可読形式にする', () {
    expect(formatFileSize(0), '0 B');
    expect(formatFileSize(100), '100 B');
    expect(formatFileSize(1023), '1023 B');
    expect(formatFileSize(1024), '1 KB');
    expect(formatFileSize(1536), '1.5 KB');
    expect(formatFileSize(1048576), '1 MB');
    expect(formatFileSize(1352914698), '1.3 GB');
    expect(formatFileSize(8589934592), '8 GB');
    expect(formatFileSize(-1), '―');
  });

  test('フレームレートを表示用にする', () {
    expect(formatFrameRate(29.97), '29.97 fps');
    expect(formatFrameRate(59.94), '59.94 fps');
    expect(formatFrameRate(60), '60 fps');
  });

  test('サンプリングレートを表示用にする', () {
    expect(formatSamplingRate(48000), '48 kHz');
    expect(formatSamplingRate(44100), '44.1 kHz');
    expect(formatSamplingRate(96000), '96 kHz');
    expect(formatSamplingRate(500), '500 Hz');
    expect(formatSamplingRate(-1), '―');
  });

  test('解像度を表示用にする', () {
    expect(formatResolution(1920, 1080), '1920 × 1080');
    expect(formatResolution(1440, 1080), '1440 × 1080');
    expect(formatResolution(null, 1080), '―');
    expect(formatResolution(1920, null), '―');
  });

  test('スキャン方式を日本語表示にする', () {
    expect(formatScanType('Interlaced'), 'インターレース');
    expect(formatScanType('Progressive'), 'プログレッシブ');
    expect(formatScanType(null), '―');
    expect(formatScanType(''), '―');
    expect(formatScanType('Unknown'), 'Unknown');
  });

  test('音声チャンネルを日本語表示にする', () {
    expect(formatAudioChannel('Monaural'), 'モノラル');
    expect(formatAudioChannel('Stereo'), 'ステレオ');
    expect(formatAudioChannel('5.1ch'), '5.1ch');
    expect(formatAudioChannel(null), '―');
    expect(formatAudioChannel(''), '―');
  });

  test('録画期間を開始〜終了形式にする', () {
    expect(
      formatRecordingPeriod(
        DateTime(2026, 10, 1, 1, 0),
        DateTime(2026, 10, 1, 1, 48),
      ),
      '2026/10/01 (木) 01:00 〜 2026/10/01 (木) 01:48',
    );
    expect(
      formatRecordingPeriod(DateTime(2026, 10, 1, 1, 0), null),
      '2026/10/01 (木) 01:00 〜',
    );
    expect(
      formatRecordingPeriod(null, DateTime(2026, 10, 1, 1, 48)),
      '〜 2026/10/01 (木) 01:48',
    );
    expect(formatRecordingPeriod(null, null), '―');
  });

  test('日時と文字列の不明時はダッシュにする', () {
    expect(formatFileDateTime(null), '―');
    expect(
      formatFileDateTime(DateTime(2026, 10, 1, 2, 0)),
      '2026/10/01 (木) 02:00',
    );
    expect(formatMediaText(null), '―');
    expect(formatMediaText(''), '―');
    expect(formatMediaText('H.264'), 'H.264');
  });
}
