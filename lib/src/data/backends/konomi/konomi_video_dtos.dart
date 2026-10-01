import 'package:json_annotation/json_annotation.dart';

import 'konomi_dtos.dart';

part 'konomi_video_dtos.g.dart';

/// 録画番組に紐づくチャンネル情報。使うフィールドのみ定義し、未知は読み捨てる。
@JsonSerializable(fieldRename: FieldRename.snake)
class KonomiVideoChannelDto {
  const KonomiVideoChannelDto({
    this.displayChannelId,
    this.name,
    this.type,
    this.networkId,
    this.serviceId,
    this.channelNumber,
  });

  factory KonomiVideoChannelDto.fromJson(Map<String, dynamic> json) =>
      _$KonomiVideoChannelDtoFromJson(json);

  final String? displayChannelId;
  final String? name;
  final String? type;
  final int? networkId;
  final int? serviceId;
  final String? channelNumber;

  Map<String, dynamic> toJson() => _$KonomiVideoChannelDtoToJson(this);
}

/// `RecordedProgram.recorded_video` の録画ファイル情報。使う分のみ定義する。
@JsonSerializable(fieldRename: FieldRename.snake)
class KonomiRecordedVideoDto {
  const KonomiRecordedVideoDto({
    this.filePath = '',
    this.fileSize = 0,
    this.fileModifiedAt,
    this.recordingStartTime,
    this.recordingEndTime,
    this.videoCodec,
    this.videoResolutionWidth,
    this.videoResolutionHeight,
    this.videoFrameRate,
    this.videoScanType,
    this.primaryAudioCodec,
    this.primaryAudioChannel,
    this.primaryAudioSamplingRate,
  });

  factory KonomiRecordedVideoDto.fromJson(Map<String, dynamic> json) =>
      _$KonomiRecordedVideoDtoFromJson(json);

  final String filePath;
  final int fileSize;
  final DateTime? fileModifiedAt;
  final DateTime? recordingStartTime;
  final DateTime? recordingEndTime;
  final String? videoCodec;
  final int? videoResolutionWidth;
  final int? videoResolutionHeight;
  final double? videoFrameRate;
  final String? videoScanType;
  final String? primaryAudioCodec;
  final String? primaryAudioChannel;
  final int? primaryAudioSamplingRate;

  Map<String, dynamic> toJson() => _$KonomiRecordedVideoDtoToJson(this);
}

/// `GET /api/videos` 配下の録画番組1件。使わないフィールドは定義しない。
@JsonSerializable(fieldRename: FieldRename.snake)
class KonomiRecordedProgramDto {
  const KonomiRecordedProgramDto({
    required this.id,
    required this.title,
    this.seriesTitle,
    this.episodeNumber,
    this.subtitle,
    this.description = '',
    this.detail = const {},
    required this.startTime,
    required this.endTime,
    this.duration = 0,
    this.genres = const [],
    this.channel,
    this.recordedVideo,
  });

  factory KonomiRecordedProgramDto.fromJson(Map<String, dynamic> json) =>
      _$KonomiRecordedProgramDtoFromJson(json);

  final int id;
  final String title;
  final String? seriesTitle;
  final String? episodeNumber;
  final String? subtitle;
  final String description;
  final Map<String, String> detail;
  final DateTime startTime;
  final DateTime endTime;
  final double duration;
  final List<KonomiGenreDto> genres;

  /// 放送チャンネル。チャンネル不明の録画では null。
  final KonomiVideoChannelDto? channel;

  /// 録画ファイル情報。録画中の番組などで欠ける場合は null。
  final KonomiRecordedVideoDto? recordedVideo;

  Map<String, dynamic> toJson() => _$KonomiRecordedProgramDtoToJson(this);
}

/// `GET /api/videos` / `/api/videos/search` のレスポンス。
@JsonSerializable(fieldRename: FieldRename.snake)
class KonomiRecordedProgramsResponse {
  const KonomiRecordedProgramsResponse({
    this.total = 0,
    this.recordedPrograms = const [],
  });

  factory KonomiRecordedProgramsResponse.fromJson(Map<String, dynamic> json) =>
      _$KonomiRecordedProgramsResponseFromJson(json);

  final int total;
  final List<KonomiRecordedProgramDto> recordedPrograms;

  Map<String, dynamic> toJson() => _$KonomiRecordedProgramsResponseToJson(this);
}
