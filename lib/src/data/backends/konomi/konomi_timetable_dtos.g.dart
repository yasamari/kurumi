// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'konomi_timetable_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KonomiTimetableProgramDto _$KonomiTimetableProgramDtoFromJson(
  Map<String, dynamic> json,
) => KonomiTimetableProgramDto(
  eventId: (json['event_id'] as num).toInt(),
  title: json['title'] as String,
  description: json['description'] as String,
  startTime: parseKonomiDateTime(json['start_time'] as String),
  endTime: parseKonomiDateTime(json['end_time'] as String),
  genres:
      (json['genres'] as List<dynamic>?)
          ?.map((e) => KonomiGenreDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  detail:
      (json['detail'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
);

Map<String, dynamic> _$KonomiTimetableProgramDtoToJson(
  KonomiTimetableProgramDto instance,
) => <String, dynamic>{
  'event_id': instance.eventId,
  'title': instance.title,
  'description': instance.description,
  'start_time': instance.startTime.toIso8601String(),
  'end_time': instance.endTime.toIso8601String(),
  'genres': instance.genres,
  'detail': instance.detail,
};

KonomiTimetableChannelInfoDto _$KonomiTimetableChannelInfoDtoFromJson(
  Map<String, dynamic> json,
) => KonomiTimetableChannelInfoDto(
  displayChannelId: json['display_channel_id'] as String,
  networkId: (json['network_id'] as num).toInt(),
  serviceId: (json['service_id'] as num).toInt(),
  type: json['type'] as String,
  name: json['name'] as String,
  remoconId: (json['remocon_id'] as num?)?.toInt(),
  channelNumber: json['channel_number'] as String?,
);

Map<String, dynamic> _$KonomiTimetableChannelInfoDtoToJson(
  KonomiTimetableChannelInfoDto instance,
) => <String, dynamic>{
  'display_channel_id': instance.displayChannelId,
  'network_id': instance.networkId,
  'service_id': instance.serviceId,
  'type': instance.type,
  'name': instance.name,
  'remocon_id': instance.remoconId,
  'channel_number': instance.channelNumber,
};

KonomiTimetableChannelDto _$KonomiTimetableChannelDtoFromJson(
  Map<String, dynamic> json,
) => KonomiTimetableChannelDto(
  channel: KonomiTimetableChannelInfoDto.fromJson(
    json['channel'] as Map<String, dynamic>,
  ),
  programs:
      (json['programs'] as List<dynamic>?)
          ?.map(
            (e) =>
                KonomiTimetableProgramDto.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  subchannels: (json['subchannels'] as List<dynamic>?)
      ?.map(
        (e) => KonomiTimetableSubchannelDto.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
);

Map<String, dynamic> _$KonomiTimetableChannelDtoToJson(
  KonomiTimetableChannelDto instance,
) => <String, dynamic>{
  'channel': instance.channel,
  'programs': instance.programs,
  'subchannels': instance.subchannels,
};

KonomiTimetableSubchannelDto _$KonomiTimetableSubchannelDtoFromJson(
  Map<String, dynamic> json,
) => KonomiTimetableSubchannelDto(
  channel: KonomiTimetableChannelInfoDto.fromJson(
    json['channel'] as Map<String, dynamic>,
  ),
  programs:
      (json['programs'] as List<dynamic>?)
          ?.map(
            (e) =>
                KonomiTimetableProgramDto.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$KonomiTimetableSubchannelDtoToJson(
  KonomiTimetableSubchannelDto instance,
) => <String, dynamic>{
  'channel': instance.channel,
  'programs': instance.programs,
};

KonomiTimetableResponse _$KonomiTimetableResponseFromJson(
  Map<String, dynamic> json,
) => KonomiTimetableResponse(
  channels:
      (json['channels'] as List<dynamic>?)
          ?.map(
            (e) =>
                KonomiTimetableChannelDto.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$KonomiTimetableResponseToJson(
  KonomiTimetableResponse instance,
) => <String, dynamic>{'channels': instance.channels};
