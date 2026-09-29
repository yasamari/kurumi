// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mirakurun_service_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MirakurunChannelDto _$MirakurunChannelDtoFromJson(Map<String, dynamic> json) =>
    MirakurunChannelDto(
      type: json['type'] as String,
      channel: json['channel'] as String,
    );

Map<String, dynamic> _$MirakurunChannelDtoToJson(
  MirakurunChannelDto instance,
) => <String, dynamic>{'type': instance.type, 'channel': instance.channel};

MirakurunServiceDto _$MirakurunServiceDtoFromJson(Map<String, dynamic> json) =>
    MirakurunServiceDto(
      id: (json['id'] as num).toInt(),
      serviceId: (json['serviceId'] as num).toInt(),
      networkId: (json['networkId'] as num).toInt(),
      name: json['name'] as String,
      remoteControlKeyId: (json['remoteControlKeyId'] as num?)?.toInt(),
      hasLogoData: json['hasLogoData'] as bool?,
      channel: json['channel'] == null
          ? null
          : MirakurunChannelDto.fromJson(
              json['channel'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$MirakurunServiceDtoToJson(
  MirakurunServiceDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'serviceId': instance.serviceId,
  'networkId': instance.networkId,
  'name': instance.name,
  'remoteControlKeyId': instance.remoteControlKeyId,
  'hasLogoData': instance.hasLogoData,
  'channel': instance.channel,
};
