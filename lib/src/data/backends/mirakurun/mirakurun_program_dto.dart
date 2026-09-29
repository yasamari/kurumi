import 'package:json_annotation/json_annotation.dart';

part 'mirakurun_program_dto.g.dart';

/// `GET /api/programs` の1要素。
///
/// `startAt` は UNIX時間(ms)、`duration` はミリ秒。
@JsonSerializable()
class MirakurunProgramDto {
  const MirakurunProgramDto({
    required this.id,
    required this.eventId,
    required this.serviceId,
    required this.networkId,
    required this.startAt,
    required this.duration,
    this.name,
    this.description,
  });

  factory MirakurunProgramDto.fromJson(Map<String, dynamic> json) =>
      _$MirakurunProgramDtoFromJson(json);

  final int id;
  final int eventId;
  final int serviceId;
  final int networkId;
  final int startAt;
  final int duration;
  final String? name;
  final String? description;

  Map<String, dynamic> toJson() => _$MirakurunProgramDtoToJson(this);
}
