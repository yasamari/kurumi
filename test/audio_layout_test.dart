import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/ts/audio_layout.dart';
import 'package:kurumi/src/data/ts/eit.dart';

/// 音声コンポーネント記述子 (0xC4) を組み立てる。
///
/// `component_type` は `component_type` / `component_tag` を詰めた2バイト目の
/// 値をそのまま使う ([AudioComponentDescriptor] と同じ配置)。
Uint8List _audioComponentDescriptor({
  required int componentType,
  bool mainComponentFlag = true,
  String language = 'jpn',
}) {
  return Uint8List.fromList([
    0xC4,
    9,
    0xF2, // reserved (0b1111) + stream_content 0b0010 (音声)
    componentType,
    0x01, // component_tag
    0x0F, // stream_type (MPEG-1 Layer II)
    0x00, // simulcast_group_tag
    // ES_multi_lingual_flag / main_component_flag / quality / sampling_rate
    mainComponentFlag ? 0x4A : 0x8A,
    ...language.codeUnits,
  ]);
}

List<EitDescriptor> _descriptorsOf(List<Uint8List> raw) =>
    parseDescriptors(Uint8List.fromList([for (final d in raw) ...d]));

void main() {
  group('音声コンポーネント記述子から音声構成を判定する', () {
    test('1/0+1/0モードはデュアルモノラル', () {
      final descriptors = _descriptorsOf([
        _audioComponentDescriptor(componentType: 0x02),
      ]);
      expect(detectLiveAudioLayout(descriptors), LiveAudioLayout.dualMono);
    });

    test('1/0モードと2/0モードは主音声のみ', () {
      for (final componentType in [0x01, 0x03]) {
        expect(
          detectLiveAudioLayout(
            _descriptorsOf([
              _audioComponentDescriptor(componentType: componentType),
            ]),
          ),
          LiveAudioLayout.mainAudioOnly,
          reason: 'component_type $componentType',
        );
      }
    });

    test('3/0以上・音声解説・聴覚障害者用音声はmpvに委ねる', () {
      // 判定しない = unknown。マルチチャンネルは mpv の認識に任せる。
      for (final componentType in [
        0x04, // 2/1モード
        0x07, // 3/1モード
        0x09, // 3/2+LFEモード
        0x0C, // 5/2.1モード
        0x0B, // 2/0/0-2/0/2-0.1モード
        0x40, // 視覚障害者用音声解説
        0x41, // 聴覚障害者用音声
        0x00, // 将来使用のためリザーブ
      ]) {
        expect(
          detectLiveAudioLayout(
            _descriptorsOf([
              _audioComponentDescriptor(componentType: componentType),
            ]),
          ),
          LiveAudioLayout.unknown,
          reason: 'component_type $componentType',
        );
      }
    });

    test('副音声の記述子 (別トラック) は判定に使わない', () {
      // main_component_flag が偽だけなら判定しない (二重ステレオ)。
      expect(
        detectLiveAudioLayout(
          _descriptorsOf([
            _audioComponentDescriptor(
              componentType: 0x02,
              mainComponentFlag: false,
            ),
          ]),
        ),
        LiveAudioLayout.unknown,
      );
    });

    test('主音声の記述子が複数あれば最初の1件を採用する', () {
      final descriptors = _descriptorsOf([
        _audioComponentDescriptor(componentType: 0x02),
        _audioComponentDescriptor(componentType: 0x03),
      ]);
      expect(detectLiveAudioLayout(descriptors), LiveAudioLayout.dualMono);
    });

    test('副音声の記述子が先に来ても主音声を見る', () {
      final descriptors = _descriptorsOf([
        _audioComponentDescriptor(
          componentType: 0x03,
          mainComponentFlag: false,
        ),
        _audioComponentDescriptor(componentType: 0x02),
      ]);
      expect(detectLiveAudioLayout(descriptors), LiveAudioLayout.dualMono);
    });

    test('音声コンポーネント記述子が無ければ判定しない', () {
      expect(detectLiveAudioLayout(const []), LiveAudioLayout.unknown);
    });

    test('他の記述子しか無ければ判定しない', () {
      final descriptors = _descriptorsOf([
        Uint8List.fromList([
          0x4D, 5, // short_event_descriptor
          0x6A, 0x70, 0x6E, // language
          0x00, // event_name_length
          0x00, // text_length
        ]),
      ]);
      expect(descriptors, hasLength(1));
      expect(detectLiveAudioLayout(descriptors), LiveAudioLayout.unknown);
    });
  });
}