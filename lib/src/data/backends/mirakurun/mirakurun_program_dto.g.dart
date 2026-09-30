// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mirakurun_program_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MirakurunProgramDto _$MirakurunProgramDtoFromJson(Map<String, dynamic> json) =>
    MirakurunProgramDto(
      id: (json['id'] as num).toInt(),
      eventId: (json['eventId'] as num).toInt(),
      serviceId: (json['serviceId'] as num).toInt(),
      networkId: (json['networkId'] as num).toInt(),
      startAt: (json['startAt'] as num).toInt(),
      duration: (json['duration'] as num).toInt(),
      name: json['name'] as String?,
      description: json['description'] as String?,
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map(
                (e) => MirakurunProgramGenreDto.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
      extended: json['extended'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$MirakurunProgramDtoToJson(
  MirakurunProgramDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'eventId': instance.eventId,
  'serviceId': instance.serviceId,
  'networkId': instance.networkId,
  'startAt': instance.startAt,
  'duration': instance.duration,
  'name': instance.name,
  'description': instance.description,
  'genres': instance.genres,
  'extended': instance.extended,
};

MirakurunProgramGenreDto _$MirakurunProgramGenreDtoFromJson(
  Map<String, dynamic> json,
) => MirakurunProgramGenreDto(
  lv1: (json['lv1'] as num?)?.toInt(),
  lv2: (json['lv2'] as num?)?.toInt(),
);

Map<String, dynamic> _$MirakurunProgramGenreDtoToJson(
  MirakurunProgramGenreDto instance,
) => <String, dynamic>{'lv1': instance.lv1, 'lv2': instance.lv2};
