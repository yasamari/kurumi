/// 対応バックエンド種別。
enum BackendType {
  mirakurun,
  konomiTv;

  String get label => switch (this) {
        BackendType.mirakurun => 'Mirakurun',
        BackendType.konomiTv => 'KonomiTV',
      };

  static BackendType fromName(String? name) => values.firstWhere(
        (type) => type.name == name,
        orElse: () => BackendType.mirakurun,
      );
}
