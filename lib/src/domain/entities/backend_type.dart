/// 対応バックエンド種別。
///
/// 新バックエンド追加時は [label] だけでなく下の能力 getter の switch にも
/// 1行ずつ追加する。網羅 switch のため書き忘れはコンパイルエラーになる。
enum BackendType {
  mirakurun,
  konomiTv;

  String get label => switch (this) {
        BackendType.mirakurun => 'Mirakurun',
        BackendType.konomiTv => 'KonomiTV',
      };

  /// ビデオ画面を利用できるかどうか。
  bool get supportsVideos => switch (this) {
        BackendType.mirakurun => false,
        BackendType.konomiTv => true,
      };

  /// 録画予約画面を利用できるかどうか。
  bool get supportsRecordingReservations => switch (this) {
        BackendType.mirakurun => false,
        BackendType.konomiTv => true,
      };

  static BackendType fromName(String? name) => values.firstWhere(
        (type) => type.name == name,
        orElse: () => BackendType.mirakurun,
      );
}
