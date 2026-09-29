import 'package:json_annotation/json_annotation.dart';

part 'mirakurun_service_dto.g.dart';

/// `GET /api/services` の1要素。不要フィールドは読み捨てる。
@JsonSerializable()
class MirakurunChannelDto {
  const MirakurunChannelDto({
    required this.type,
    required this.channel,
  });

  factory MirakurunChannelDto.fromJson(Map<String, dynamic> json) =>
      _$MirakurunChannelDtoFromJson(json);

  final String type;
  final String channel;

  Map<String, dynamic> toJson() => _$MirakurunChannelDtoToJson(this);
}

@JsonSerializable()
class MirakurunServiceDto {
  const MirakurunServiceDto({
    required this.id,
    required this.serviceId,
    required this.networkId,
    required this.name,
    this.remoteControlKeyId,
    this.hasLogoData,
    this.channel,
  });

  factory MirakurunServiceDto.fromJson(Map<String, dynamic> json) =>
      _$MirakurunServiceDtoFromJson(json);

  final int id;
  final int serviceId;
  final int networkId;
  final String name;
  final int? remoteControlKeyId;
  final bool? hasLogoData;
  final MirakurunChannelDto? channel;

  Map<String, dynamic> toJson() => _$MirakurunServiceDtoToJson(this);
}
