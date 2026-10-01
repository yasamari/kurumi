// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'konomi_video_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KonomiVideoChannelDto _$KonomiVideoChannelDtoFromJson(
  Map<String, dynamic> json,
) => KonomiVideoChannelDto(
  displayChannelId: json['display_channel_id'] as String?,
  name: json['name'] as String?,
  type: json['type'] as String?,
  networkId: (json['network_id'] as num?)?.toInt(),
  serviceId: (json['service_id'] as num?)?.toInt(),
  channelNumber: json['channel_number'] as String?,
);

Map<String, dynamic> _$KonomiVideoChannelDtoToJson(
  KonomiVideoChannelDto instance,
) => <String, dynamic>{
  'display_channel_id': instance.displayChannelId,
  'name': instance.name,
  'type': instance.type,
  'network_id': instance.networkId,
  'service_id': instance.serviceId,
  'channel_number': instance.channelNumber,
};

KonomiRecordedVideoDto _$KonomiRecordedVideoDtoFromJson(
  Map<String, dynamic> json,
) => KonomiRecordedVideoDto(
  filePath: json['file_path'] as String? ?? '',
  fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
  fileModifiedAt: parseKonomiNullableDateTime(
    json['file_modified_at'] as String?,
  ),
  recordingStartTime: parseKonomiNullableDateTime(
    json['recording_start_time'] as String?,
  ),
  recordingEndTime: parseKonomiNullableDateTime(
    json['recording_end_time'] as String?,
  ),
  videoCodec: json['video_codec'] as String?,
  videoResolutionWidth: (json['video_resolution_width'] as num?)?.toInt(),
  videoResolutionHeight: (json['video_resolution_height'] as num?)?.toInt(),
  videoFrameRate: (json['video_frame_rate'] as num?)?.toDouble(),
  videoScanType: json['video_scan_type'] as String?,
  primaryAudioCodec: json['primary_audio_codec'] as String?,
  primaryAudioChannel: json['primary_audio_channel'] as String?,
  primaryAudioSamplingRate: (json['primary_audio_sampling_rate'] as num?)
      ?.toInt(),
);

Map<String, dynamic> _$KonomiRecordedVideoDtoToJson(
  KonomiRecordedVideoDto instance,
) => <String, dynamic>{
  'file_path': instance.filePath,
  'file_size': instance.fileSize,
  'file_modified_at': instance.fileModifiedAt?.toIso8601String(),
  'recording_start_time': instance.recordingStartTime?.toIso8601String(),
  'recording_end_time': instance.recordingEndTime?.toIso8601String(),
  'video_codec': instance.videoCodec,
  'video_resolution_width': instance.videoResolutionWidth,
  'video_resolution_height': instance.videoResolutionHeight,
  'video_frame_rate': instance.videoFrameRate,
  'video_scan_type': instance.videoScanType,
  'primary_audio_codec': instance.primaryAudioCodec,
  'primary_audio_channel': instance.primaryAudioChannel,
  'primary_audio_sampling_rate': instance.primaryAudioSamplingRate,
};

KonomiRecordedProgramDto _$KonomiRecordedProgramDtoFromJson(
  Map<String, dynamic> json,
) => KonomiRecordedProgramDto(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  seriesTitle: json['series_title'] as String?,
  episodeNumber: json['episode_number'] as String?,
  subtitle: json['subtitle'] as String?,
  description: json['description'] as String? ?? '',
  detail:
      (json['detail'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  startTime: parseKonomiDateTime(json['start_time'] as String),
  endTime: parseKonomiDateTime(json['end_time'] as String),
  duration: (json['duration'] as num?)?.toDouble() ?? 0,
  genres:
      (json['genres'] as List<dynamic>?)
          ?.map((e) => KonomiGenreDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  channel: json['channel'] == null
      ? null
      : KonomiVideoChannelDto.fromJson(json['channel'] as Map<String, dynamic>),
  recordedVideo: json['recorded_video'] == null
      ? null
      : KonomiRecordedVideoDto.fromJson(
          json['recorded_video'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$KonomiRecordedProgramDtoToJson(
  KonomiRecordedProgramDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'series_title': instance.seriesTitle,
  'episode_number': instance.episodeNumber,
  'subtitle': instance.subtitle,
  'description': instance.description,
  'detail': instance.detail,
  'start_time': instance.startTime.toIso8601String(),
  'end_time': instance.endTime.toIso8601String(),
  'duration': instance.duration,
  'genres': instance.genres,
  'channel': instance.channel,
  'recorded_video': instance.recordedVideo,
};

KonomiRecordedProgramsResponse _$KonomiRecordedProgramsResponseFromJson(
  Map<String, dynamic> json,
) => KonomiRecordedProgramsResponse(
  total: (json['total'] as num?)?.toInt() ?? 0,
  recordedPrograms:
      (json['recorded_programs'] as List<dynamic>?)
          ?.map(
            (e) => KonomiRecordedProgramDto.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$KonomiRecordedProgramsResponseToJson(
  KonomiRecordedProgramsResponse instance,
) => <String, dynamic>{
  'total': instance.total,
  'recorded_programs': instance.recordedPrograms,
};
