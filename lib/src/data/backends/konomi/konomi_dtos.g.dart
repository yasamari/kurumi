// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'konomi_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KonomiProgramDto _$KonomiProgramDtoFromJson(Map<String, dynamic> json) =>
    KonomiProgramDto(
      eventId: (json['event_id'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
    );

Map<String, dynamic> _$KonomiProgramDtoToJson(KonomiProgramDto instance) =>
    <String, dynamic>{
      'event_id': instance.eventId,
      'title': instance.title,
      'description': instance.description,
      'start_time': instance.startTime.toIso8601String(),
      'end_time': instance.endTime.toIso8601String(),
    };

KonomiChannelDto _$KonomiChannelDtoFromJson(Map<String, dynamic> json) =>
    KonomiChannelDto(
      id: json['id'] as String,
      displayChannelId: json['display_channel_id'] as String,
      networkId: (json['network_id'] as num).toInt(),
      serviceId: (json['service_id'] as num).toInt(),
      type: json['type'] as String,
      name: json['name'] as String,
      isDisplay: json['is_display'] as bool,
      remoconId: (json['remocon_id'] as num?)?.toInt(),
      channelNumber: json['channel_number'] as String?,
      programPresent: json['program_present'] == null
          ? null
          : KonomiProgramDto.fromJson(
              json['program_present'] as Map<String, dynamic>,
            ),
      programFollowing: json['program_following'] == null
          ? null
          : KonomiProgramDto.fromJson(
              json['program_following'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$KonomiChannelDtoToJson(KonomiChannelDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'display_channel_id': instance.displayChannelId,
      'network_id': instance.networkId,
      'service_id': instance.serviceId,
      'type': instance.type,
      'name': instance.name,
      'is_display': instance.isDisplay,
      'remocon_id': instance.remoconId,
      'channel_number': instance.channelNumber,
      'program_present': instance.programPresent,
      'program_following': instance.programFollowing,
    };

KonomiChannelsResponse _$KonomiChannelsResponseFromJson(
  Map<String, dynamic> json,
) => KonomiChannelsResponse(
  gr:
      (json['GR'] as List<dynamic>?)
          ?.map((e) => KonomiChannelDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  bs:
      (json['BS'] as List<dynamic>?)
          ?.map((e) => KonomiChannelDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  cs:
      (json['CS'] as List<dynamic>?)
          ?.map((e) => KonomiChannelDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  catv:
      (json['CATV'] as List<dynamic>?)
          ?.map((e) => KonomiChannelDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  sky:
      (json['SKY'] as List<dynamic>?)
          ?.map((e) => KonomiChannelDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  bs4k:
      (json['BS4K'] as List<dynamic>?)
          ?.map((e) => KonomiChannelDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$KonomiChannelsResponseToJson(
  KonomiChannelsResponse instance,
) => <String, dynamic>{
  'GR': instance.gr,
  'BS': instance.bs,
  'CS': instance.cs,
  'CATV': instance.catv,
  'SKY': instance.sky,
  'BS4K': instance.bs4k,
};
