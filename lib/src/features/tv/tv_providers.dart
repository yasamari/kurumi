import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/settings/app_settings.dart';
import '../../data/backends/mirakurun/mirakurun_epg_channel_item.dart';
import '../../domain/entities/backend_type.dart';
import '../../domain/entities/channel_item.dart';
import '../../domain/providers/backend_provider.dart';
import '../../domain/repositories/tv_repository.dart';
import 'epg_providers.dart';

part 'tv_providers.g.dart';

/// 一覧の次回更新時刻 (ms epoch) を返す純粋関数。
///
/// 現在放送中の番組の終了時刻と次番組の開始時刻のうち、現在より未来で
/// 最も早いもの。いずれかの番組が切り替わる瞬間に一覧を作り直すための時刻。
/// 有効な境界がなければ 60秒後を返す。
int nextChannelListTickMs({
  required List<ChannelItem> items,
  required int nowMs,
}) {
  int? tickMs;
  for (final item in items) {
    final presentEnd = item.nowOnAir?.endAt.millisecondsSinceEpoch;
    if (presentEnd != null &&
        presentEnd > nowMs &&
        (tickMs == null || presentEnd < tickMs)) {
      tickMs = presentEnd;
    }
    final nextStart = item.nextUp?.startAt.millisecondsSinceEpoch;
    if (nextStart != null &&
        nextStart > nowMs &&
        (tickMs == null || nextStart < tickMs)) {
      tickMs = nextStart;
    }
  }
  return tickMs ?? nowMs + _tickFallbackMs;
}

/// 有効な番組境界がないときの更新間隔。
const _tickFallbackMs = 60 * 1000;

/// KonomiTV 再取得の最短間隔。サーバー時刻のずれ等で境界が過去を指しても
/// サーバーを叩き続けないようにする。
const _konomiRefetchFloorMs = 30 * 1000;

/// 放送中チャンネル一覧。未設定時は [BackendUnconfiguredException] を送出し、
/// UI側で設定誘導表示に切り替える。
///
/// KonomiTV はリポジトリから都度取得する。Mirakurun はEPGキャッシュから
/// 組み立てる (通信なし)。Mirakurun の表示は時刻の進行でのみ再計算される。
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
  final backendType = ref.watch(
    appSettingsProvider.select(
      (settings) => settings.value?.backendType ?? BackendType.mirakurun,
    ),
  );
  final List<ChannelItem> items;
  if (backendType == BackendType.konomiTv) {
    final repository = ref.watch(tvRepositoryProvider);
    items = await repository.getNowOnAirChannels();
  } else {
    // Mirakurun: 同期を済ませてからキャッシュを読む。通信は起きない。
    // 視聴中のプレイヤーに波及させないよう、ストリーム解決 ([liveStream])
    // はこちらではなく時刻非依存の [mirakurunEpgChannel] を使う。
    await ref.watch(mirakurunEpgSyncProvider.future);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dao = ref.watch(epgDatabaseProvider).epgDao;
    final baseUrl = ref.watch(
      appSettingsProvider.select(
        (settings) => settings.value?.mirakurunBaseUrl ?? '',
      ),
    );
    final rows = await dao.nowOnAir(
      sourceBackend: BackendType.mirakurun.name,
      nowMs: nowMs,
    );
    items = [
      for (final row in rows) channelItemFromEpgRow(row, baseUrl: baseUrl),
    ];
  }
  // 次の番組境界で自分を作り直す。KonomiTV は再取得、Mirakurun は再計算。
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final delayMs = nextChannelListTickMs(items: items, nowMs: nowMs) - nowMs;
  final floorMs = backendType == BackendType.konomiTv
      ? _konomiRefetchFloorMs
      : 0;
  final timer = Timer(
    Duration(milliseconds: delayMs < floorMs ? floorMs : delayMs),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return items;
}
