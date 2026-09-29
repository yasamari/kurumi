import 'package:freezed_annotation/freezed_annotation.dart';

part 'channel_type.freezed.dart';

/// バックエンド非依存のチャンネル種別。
@freezed
sealed class ChannelType with _$ChannelType {
  const factory ChannelType.gr() = ChannelTypeGr;
  const factory ChannelType.bs() = ChannelTypeBs;
  const factory ChannelType.cs() = ChannelTypeCs;
  const factory ChannelType.sky() = ChannelTypeSky;
  const factory ChannelType.catv() = ChannelTypeCatv;
  const factory ChannelType.bs4k() = ChannelTypeBs4k;
  const factory ChannelType.unknown() = ChannelTypeUnknown;
}

/// APIの文字列表現から [ChannelType] に変換する。
ChannelType channelTypeFromString(String? value) {
  return switch (value?.toUpperCase()) {
    'GR' => const ChannelType.gr(),
    'BS' => const ChannelType.bs(),
    'CS' => const ChannelType.cs(),
    'SKY' => const ChannelType.sky(),
    'CATV' => const ChannelType.catv(),
    'BS4K' => const ChannelType.bs4k(),
    _ => const ChannelType.unknown(),
  };
}

/// タブ表示用のラベルと並び順。
extension ChannelTypeUi on ChannelType {
  String get label => switch (this) {
        ChannelTypeGr() => '地デジ',
        ChannelTypeBs() => 'BS',
        ChannelTypeCs() => 'CS',
        ChannelTypeCatv() => 'CATV',
        ChannelTypeSky() => 'SKY',
        ChannelTypeBs4k() => 'BS4K',
        ChannelTypeUnknown() => 'その他',
      };

  int get sortOrder => switch (this) {
        ChannelTypeGr() => 0,
        ChannelTypeBs() => 1,
        ChannelTypeCs() => 2,
        ChannelTypeCatv() => 3,
        ChannelTypeSky() => 4,
        ChannelTypeBs4k() => 5,
        ChannelTypeUnknown() => 6,
      };
}

/// チャンネル一覧に含まれる種別を正規順で重複なく返す。
List<ChannelType> channelTypesInOrder(Iterable<ChannelType> types) {
  final unique = types.toSet().toList();
  unique.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return unique;
}
