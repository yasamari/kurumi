import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:kurumi/src/data/ts/audio_layout.dart';
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

    test('どちらも無ければ1本目は主音声・2本目は副音声', () {
      expect(audioTrackLabel(index: 1), '主音声');
      expect(audioTrackLabel(index: 2), '副音声');
      expect(audioTrackLabel(title: '  ', language: '', index: 3), '音声3');
    });
  });

  group('再生中の音声トラックの位置', () {
    const tracks = [
      AudioTrack('1', null, null),
      AudioTrack('2', null, null),
    ];

    test('一覧にあればその位置', () {
      expect(
        currentAudioTrackIndex(tracks: tracks, current: tracks[1]),
        1,
      );
    });

    test('auto など一覧に無ければ先頭', () {
      expect(
        currentAudioTrackIndex(tracks: tracks, current: AudioTrack.auto()),
        0,
      );
    });

    test('空なら -1', () {
      expect(
        currentAudioTrackIndex(
          tracks: const [],
          current: AudioTrack.auto(),
        ),
        -1,
      );
    });
  });

  group('音声ページの表示方法', () {
    test('mpv が2本以上ならトラック一覧 (EIT の判定より優先)', () {
      expect(
        audioMenuMode(
          realAudioTrackCount: 2,
          layout: LiveAudioLayout.dualMono,
        ),
        AudioMenuMode.tracks,
      );
      expect(
        audioMenuMode(
          realAudioTrackCount: 2,
          layout: LiveAudioLayout.unknown,
        ),
        AudioMenuMode.tracks,
      );
    });

    test('1本でデュアルモノラルなら主音声・副音声だけ', () {
      expect(
        audioMenuMode(
          realAudioTrackCount: 1,
          layout: LiveAudioLayout.dualMono,
        ),
        AudioMenuMode.dualMono,
      );
    });

    test('主音声のみ・判定不能・0本なら1行だけ', () {
      for (final layout in [
        LiveAudioLayout.mainAudioOnly,
        LiveAudioLayout.unknown,
      ]) {
        expect(
          audioMenuMode(realAudioTrackCount: 1, layout: layout),
          AudioMenuMode.single,
          reason: '$layout',
        );
      }
      expect(
        audioMenuMode(
          realAudioTrackCount: 0,
          layout: LiveAudioLayout.dualMono,
        ),
        AudioMenuMode.dualMono,
      );
    });
  });

  group('音声の表示名', () {
    const oneTrack = [AudioTrack('1', null, null)];
    const twoTracks = [AudioTrack('1', null, null), AudioTrack('2', null, null)];

    test('トラック一覧なら再生中のトラックの名', () {
      expect(
        audioMenuLabel(
          mode: AudioMenuMode.tracks,
          layout: LiveAudioLayout.unknown,
          realAudioTracks: twoTracks,
          current: twoTracks[1],
          dualMonoChannel: null,
        ),
        '副音声',
      );
    });

    test('dual mono は現在のチャンネル名、未選択は主音声', () {
      expect(
        audioMenuLabel(
          mode: AudioMenuMode.dualMono,
          layout: LiveAudioLayout.dualMono,
          realAudioTracks: oneTrack,
          current: oneTrack.first,
          dualMonoChannel: null,
        ),
        '主音声',
      );
      expect(
        audioMenuLabel(
          mode: AudioMenuMode.dualMono,
          layout: LiveAudioLayout.dualMono,
          realAudioTracks: oneTrack,
          current: oneTrack.first,
          dualMonoChannel: DualMonoChannel.sub,
        ),
        '副音声',
      );
    });

    test('選べないときは主音声とだけ表示する', () {
      expect(
        audioMenuLabel(
          mode: AudioMenuMode.single,
          layout: LiveAudioLayout.mainAudioOnly,
          realAudioTracks: oneTrack,
          current: oneTrack.first,
          dualMonoChannel: null,
        ),
        '主音声',
      );
    });

    test('判定不能の1本は mpv のトラック名をそのまま出す', () {
      expect(
        audioMenuLabel(
          mode: AudioMenuMode.single,
          layout: LiveAudioLayout.unknown,
          realAudioTracks: const [AudioTrack('1', '5.1', null)],
          current: AudioTrack('1', '5.1', null),
          dualMonoChannel: null,
        ),
        '5.1',
      );
      // mpv がまだトラックを返していなくても落とさない。
      expect(
        audioMenuLabel(
          mode: AudioMenuMode.single,
          layout: LiveAudioLayout.unknown,
          realAudioTracks: const [],
          current: AudioTrack.auto(),
          dualMonoChannel: null,
        ),
        '主音声',
      );
    });
  });
}
