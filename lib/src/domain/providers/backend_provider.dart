import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/app_settings_state.dart';
import '../entities/backend_type.dart';
import '../repositories/tv_repository.dart';
import '../../data/backends/konomi/konomi_repository.dart';
import '../../data/backends/mirakurun/mirakurun_repository.dart';

part 'backend_provider.g.dart';

/// 設定のバックエンド種別に応じた [TvRepository] を返す factory。
///
/// 新バックエンド追加時はこの switch に1行追加するだけ。
@riverpod
TvRepository tvRepository(Ref ref) {
  final settings =
      ref.watch(appSettingsProvider).value ?? const AppSettingsState();
  final dio = ref.watch(backendDioProvider);
  return switch (settings.backendType) {
    BackendType.mirakurun => MirakurunTvRepository(
        dio,
        baseUrl: settings.mirakurunBaseUrl,
      ),
    BackendType.konomiTv => KonomiTvRepository(
        dio,
        baseUrl: settings.konomiBaseUrl,
      ),
  };
}
