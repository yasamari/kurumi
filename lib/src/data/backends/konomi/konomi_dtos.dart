import 'package:json_annotation/json_annotation.dart';

part 'konomi_dtos.g.dart';

/// 番組ジャンル (大分類・中分類は日本語名)。
@JsonSerializable(fieldRename: FieldRename.snake)
class KonomiGenreDto {
  const KonomiGenreDto({required this.major, required this.middle});

  factory KonomiGenreDto.fromJson(Map<String, dynamic> json) =>
      _$KonomiGenreDtoFromJson(json);

  final String major;
  final String middle;

  Map<String, dynamic> toJson() => _$KonomiGenreDtoToJson(this);
}

/// `LiveChannel.program_present / program_following` の番組情報。
///
/// 使わないフィールドは定義せず、未知フィールドは読み捨てる。
/// `genres` はジャンル一覧、`detail` は番組詳細 (キー→説明文)。
@JsonSerializable(fieldRename: FieldRename.snake)
class KonomiProgramDto {
  const KonomiProgramDto({
    required this.eventId,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.genres = const [],
    this.detail = const {},
  });

  factory KonomiProgramDto.fromJson(Map<String, dynamic> json) =>
      _$KonomiProgramDtoFromJson(json);

  final int eventId;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final List<KonomiGenreDto> genres;
  final Map<String, String> detail;

  Map<String, dynamic> toJson() => _$KonomiProgramDtoToJson(this);
}

/// `GET /api/channels` 配下のチャンネル1件。
@JsonSerializable(fieldRename: FieldRename.snake)
class KonomiChannelDto {
  const KonomiChannelDto({
    required this.id,
    required this.displayChannelId,
    required this.networkId,
    required this.serviceId,
    required this.type,
    required this.name,
    required this.isDisplay,
    this.remoconId,
    this.channelNumber,
    this.programPresent,
    this.programFollowing,
  });

  factory KonomiChannelDto.fromJson(Map<String, dynamic> json) =>
      _$KonomiChannelDtoFromJson(json);

  final String id;
  final String displayChannelId;
  final int networkId;
  final int serviceId;
  final String type;
  final String name;
  final bool isDisplay;
  final int? remoconId;
  final String? channelNumber;
  final KonomiProgramDto? programPresent;
  final KonomiProgramDto? programFollowing;

  Map<String, dynamic> toJson() => _$KonomiChannelDtoToJson(this);
}

/// `GET /api/channels` のレスポンス。種別ごとに配列で返る。
@JsonSerializable()
class KonomiChannelsResponse {
  const KonomiChannelsResponse({
    this.gr = const [],
    this.bs = const [],
    this.cs = const [],
    this.catv = const [],
    this.sky = const [],
    this.bs4k = const [],
  });

  factory KonomiChannelsResponse.fromJson(Map<String, dynamic> json) =>
      _$KonomiChannelsResponseFromJson(json);

  @JsonKey(name: 'GR', defaultValue: [])
  final List<KonomiChannelDto> gr;
  @JsonKey(name: 'BS', defaultValue: [])
  final List<KonomiChannelDto> bs;
  @JsonKey(name: 'CS', defaultValue: [])
  final List<KonomiChannelDto> cs;
  @JsonKey(name: 'CATV', defaultValue: [])
  final List<KonomiChannelDto> catv;
  @JsonKey(name: 'SKY', defaultValue: [])
  final List<KonomiChannelDto> sky;
  @JsonKey(name: 'BS4K', defaultValue: [])
  final List<KonomiChannelDto> bs4k;

  /// GR→BS→CS→CATV→SKY→BS4K の順に結合する。
  List<KonomiChannelDto> get allInOrder => [...gr, ...bs, ...cs, ...catv, ...sky, ...bs4k];

  Map<String, dynamic> toJson() => _$KonomiChannelsResponseToJson(this);
}
