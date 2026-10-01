import 'package:freezed_annotation/freezed_annotation.dart';

part 'recorded_file_info.freezed.dart';

/// 録画ファイルの技術情報。ビデオ詳細のBottomSheet表示に使う。
@freezed
abstract class RecordedFileInfo with _$RecordedFileInfo {
  const factory RecordedFileInfo({
    /// 録画ファイルのサーバー上のパス。
    @Default('') String filePath,

    /// ファイルサイズ (バイト)。
    @Default(0) int fileSize,

    /// 録画の開始・終了日時。録画中の番組では null になりうる。
    DateTime? recordingStartTime,
    DateTime? recordingEndTime,

    /// ファイルの最終更新日時。
    DateTime? fileModifiedAt,

    /// 映像コーデック (例: `H.264`)。不明時は null。
    String? videoCodec,

    /// 映像解像度 (幅・高さ)。不明時は null。
    int? resolutionWidth,
    int? resolutionHeight,

    /// フレームレート (例: `29.97`)。不明時は null。
    double? frameRate,

    /// スキャン方式 (`Interlaced` / `Progressive`)。不明時は null。
    String? scanType,

    /// 音声コーデック (例: `AAC-LC`)。不明時は null。
    String? audioCodec,

    /// 音声チャンネル (`Monaural` / `Stereo` / `5.1ch`)。不明時は null。
    String? audioChannel,

    /// 音声サンプリングレート (Hz)。不明時は null。
    int? samplingRate,
  }) = _RecordedFileInfo;
}
