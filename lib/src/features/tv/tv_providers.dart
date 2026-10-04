import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/settings/app_settings.dart';
import '../../domain/entities/channel_item.dart';
import '../../domain/providers/backend_provider.dart';
import '../../domain/repositories/tv_repository.dart';

part 'tv_providers.g.dart';

/// 放送中チャンネル一覧。未設定時は [BackendUnconfiguredException] を送出し、
/// UI側で設定誘導表示に切り替える。
///
/// **設定の有無だけを選ぶ。** [appSettingsProvider.future] をそのまま購読すると、
/// 接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに future の
/// インスタンスが変わって取り直しが始まり、視聴中のプレイヤーが作り直される。
@riverpod
Future<List<ChannelItem>> nowOnAirChannels(Ref ref) async {
  final isConfigured = await ref.watch(
    appSettingsProvider.selectAsync((settings) => settings.isConfigured),
  );
  if (!isConfigured) {
    throw const BackendUnconfiguredException();
  }
  final repository = ref.watch(tvRepositoryProvider);
  return repository.getNowOnAirChannels();
}
