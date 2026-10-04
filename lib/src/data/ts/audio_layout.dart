import 'eit.dart';

/// 音声コンポーネント記述子の `component_type` (ARIB-STD-B10-2 表6-5)。
///
/// 音声 (stream_content 0b0010) の値。主・副の切替に関わるものだけを置く。
/// 1/0+1/0モード (デュアルモノラル)。
const _componentTypeDualMono = 0x02;

/// 1/0モード (シングルモノ)。主音声のみ。
const _componentTypeMono = 0x01;

/// 2/0モード (ステレオ)。副音声の切替はない。
const _componentTypeStereo = 0x03;

/// 音声コンポーネント記述子から判定した音声構成。
///
/// 判定するのは **主音声と副音声の切替が要るかどうか** だけ。3/0 以上の
/// マルチチャンネル (5.1・7.1 など)、視覚障害者用音声解説、聴覚障害者用音声、
/// 記述子の無い放送、録画再生 (TS を見ない) は [LiveAudioLayout.unknown] として
/// 扱い、mpv が得る音声トラック (media_kit の `Tracks`) の認識に委ねる。
enum LiveAudioLayout {
  /// 判定不能。mpv の音声トラック認識に委ねる。
  unknown,

  /// 主音声のみ (1/0モード・2/0モード)。副音声の切替がない。
  mainAudioOnly,

  /// 1/0+1/0モード (デュアルモノラル)。主・副音声が1本のステレオ音声に
  /// 同居している (Lch=主音声 / Rch=副音声)。
  dualMono,
}

/// EIT[p/f] の記述子から音声構成を判定する。
///
/// 音声コンポーネント記述子 (0xC4) のうち `main_component_flag` が真のものの
/// `component_type` を見る。`main_component_flag` が偽の記述子は副音声 =
/// **別の音声トラック** の存在を示すので、判定には使わない (二重ステレオは
/// mpv が2本の音声トラックとして認識する)。
///
/// [EitDescriptor] の並び順や個数に依存しないよう、主音声の記述子が複数ある
/// 場合は最初の1件を採用する。
LiveAudioLayout detectLiveAudioLayout(List<EitDescriptor> descriptors) {
  for (final descriptor in descriptors) {
    if (descriptor is! AudioComponentDescriptor) continue;
    if (!descriptor.mainComponentFlag) continue;
    final type = descriptor.componentType;
    if (type == _componentTypeDualMono) return LiveAudioLayout.dualMono;
    // 1/0モード (シングルモノ) と 2/0モード (ステレオ) はどちらも副音声の
    // 切替がないため、同じ判定に寄せる (表示はどちらも主音声)。
    if (type == _componentTypeMono || type == _componentTypeStereo) {
      return LiveAudioLayout.mainAudioOnly;
    }
    // 3/0以上・音声解説・聴覚障害者用音声・予約値は mpv に委ねる。
    return LiveAudioLayout.unknown;
  }
  return LiveAudioLayout.unknown;
}
