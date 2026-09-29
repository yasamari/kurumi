import '../../domain/entities/backend_type.dart';

/// 永続化されるアプリ設定のスナップショット。
class AppSettingsState {
  const AppSettingsState({
    this.backendType = BackendType.mirakurun,
    this.mirakurunBaseUrl = '',
    this.konomiBaseUrl = '',
  });

  final BackendType backendType;
  final String mirakurunBaseUrl;
  final String konomiBaseUrl;

  /// 現在選択中バックエンドのベースURL。
  String get activeBaseUrl => switch (backendType) {
        BackendType.mirakurun => mirakurunBaseUrl,
        BackendType.konomiTv => konomiBaseUrl,
      };

  /// テレビ画面を表示できる状態かどうか。
  bool get isConfigured => activeBaseUrl.isNotEmpty;

  AppSettingsState copyWith({
    BackendType? backendType,
    String? mirakurunBaseUrl,
    String? konomiBaseUrl,
  }) {
    return AppSettingsState(
      backendType: backendType ?? this.backendType,
      mirakurunBaseUrl: mirakurunBaseUrl ?? this.mirakurunBaseUrl,
      konomiBaseUrl: konomiBaseUrl ?? this.konomiBaseUrl,
    );
  }
}
