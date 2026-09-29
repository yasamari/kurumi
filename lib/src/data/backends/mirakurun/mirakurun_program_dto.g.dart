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
};
