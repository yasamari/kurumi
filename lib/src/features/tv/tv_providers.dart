import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/settings/app_settings.dart';
import '../../domain/entities/channel_item.dart';
import '../../domain/providers/backend_provider.dart';
import '../../domain/repositories/tv_repository.dart';

part 'tv_providers.g.dart';

/// 放送中チャンネル一覧。未設定時は [BackendUnconfiguredException] を送出し、
/// UI側で設定誘導表示に切り替える。
@riverpod
Future<List<ChannelItem>> nowOnAirChannels(Ref ref) async {
  final settings = await ref.watch(appSettingsProvider.future);
  if (!settings.isConfigured) {
    throw const BackendUnconfiguredException();
  }
  final repository = ref.watch(tvRepositoryProvider);
  return repository.getNowOnAirChannels();
}
