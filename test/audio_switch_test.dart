import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/features/player/audio_switch.dart';

void main() {
  group('dual_mono_mode の値', () {
    test('主音声は main、副音声は sub、未指定は auto', () {
      expect(dualMonoModeValue(DualMonoChannel.main), 'main');
      expect(dualMonoModeValue(DualMonoChannel.sub), 'sub');
      expect(dualMonoModeValue(null), 'auto');
    });

    test('mpv の ad-lavc-o に渡す文字列を組み立てる', () {
      expect(dualMonoLavcOption(DualMonoChannel.main), 'dual_mono_mode=main');
      expect(dualMonoLavcOption(DualMonoChannel.sub), 'dual_mono_mode=sub');
      // null は既定 (主＋副をステレオ出力) に戻す。
      expect(dualMonoLavcOption(null), 'dual_mono_mode=auto');
    });
  });

  group('二重モノラルの表示名', () {
    test('主音声・副音声', () {
      expect(DualMonoChannel.main.label, '主音声');
      expect(DualMonoChannel.sub.label, '副音声');
    });
  });

  group('音声トラックの表示名', () {
    test('タイトルを最優先する', () {
      expect(audioTrackLabel(title: '日本語', language: 'jpn', index: 1), '日本語');
    });

    test('タイトルが無ければ言語を使う', () {
      expect(audioTrackLabel(language: 'jpn', index: 2), 'jpn');
    });

    test('どちらも無ければ通し番号を使う', () {
      expect(audioTrackLabel(index: 1), '音声1');
      expect(audioTrackLabel(title: '  ', language: '', index: 3), '音声3');
    });
  });
}
