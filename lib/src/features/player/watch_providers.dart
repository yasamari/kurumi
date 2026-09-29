import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/backends/konomi/konomi_live.dart';
import '../../domain/entities/live_stream.dart';
import '../../domain/providers/backend_provider.dart';
import '../tv/tv_providers.dart';

part 'watch_providers.g.dart';

/// 視聴中の画質 (KonomiTV用)。永続化しない。既定は `original`。
@riverpod
class WatchQuality extends _$WatchQuality {
  @override
  String build() => defaultKonomiQuality;

  /// 画質を切り替える。不正値は `original` に正規化される。
  void setQuality(String quality) {
    state = normalizeKonomiQuality(quality);
  }
}

/// 指定チャンネルのライブストリーム情報。画質変更に追従する。
///
/// チャンネル解決は放送中一覧のキャッシュから行う。見つからなければ例外送出し、
/// UI側で「見つかりません」表示に使う。
@riverpod
Future<LiveStream> liveStream(Ref ref, String channelId) async {
  final quality = ref.watch(watchQualityProvider);
  final items = await ref.watch(nowOnAirChannelsProvider.future);
  final item = items.where((e) => e.channel.id == channelId).firstOrNull;
  if (item == null) {
    throw const ChannelNotFoundException();
  }
  final repository = ref.watch(tvRepositoryProvider);
  return repository.getLiveStream(item.channel, quality: quality);
}

/// 視聴対象チャンネルが一覧キャッシュに無い場合の例外。
class ChannelNotFoundException implements Exception {
  const ChannelNotFoundException();
}
