import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/app_settings_state.dart';
import '../../data/backends/mirakurun/mirakurun_epg_channel_item.dart';
import '../../data/backends/mirakurun/mirakurun_epg_fetcher.dart';
import '../../data/epg/epg_database.dart';
import '../../data/epg/epg_sync_policy.dart';
import '../../domain/entities/backend_type.dart';
import '../../domain/entities/channel.dart';
import '../../domain/repositories/tv_repository.dart';

part 'epg_providers.g.dart';

/// EPGキャッシュのデータベース。アプリ存続中は開きっぱなしにする。
@Riverpod(keepAlive: true)
EpgDatabase epgDatabase(Ref ref) {
  final db = EpgDatabase();
  ref.onDispose(db.close);
  return db;
}

/// 視聴対象チャンネルの解決。EPGキャッシュのチャンネル行を one-shot で読む。
///
/// 時刻に依存しないため、テレビ欄の毎分再計算の影響を受けない。
/// 視聴中のプレイヤー作り直しを避けるにはここを噛ませること
/// ([liveStream] のコメント参照)。見つからなければ
/// [ChannelNotFoundException] を送出する。
@riverpod
Future<Channel> mirakurunEpgChannel(Ref ref, String channelId) async {
  final dao = ref.watch(epgDatabaseProvider).epgDao;
  final baseUrl = ref.watch(
    appSettingsProvider.select(
      (settings) => settings.value?.mirakurunBaseUrl ?? '',
    ),
  );
  final row = await dao.getChannel(
    sourceBackend: BackendType.mirakurun.name,
    remoteId: channelId,
  );
  if (row == null) {
    throw const ChannelNotFoundException();
  }
  return channelFromEpgChannelRow(row, baseUrl: baseUrl);
}

/// Mirakurun EPGの同期状態。取得は使用中のバックエンドがMirakurunのときのみ。
///
/// - 鮮度内なら何もせず状態を返す (切替時の再取得防止)
/// - 期限切れ・未取得なら取得してDBを全置換する
/// - 接続先変更時は旧行を消してから取得する
/// - 取得失敗時は古いキャッシュがあればそれを返し、なければ例外を送出する
///   (UI側の既存エラー表示に載せる)
///
/// 次回更新時刻にタイマーを張り、自分を invalidate して再評価する。
/// KonomiTV 選択時は null を返し、何もしない。
@Riverpod(keepAlive: true)
Future<EpgSyncState?> mirakurunEpgSync(Ref ref) async {
  final endpoint = ref.watch(
    appSettingsProvider.select(
      (settings) => (
        type: settings.value?.backendType ?? BackendType.mirakurun,
        baseUrl: settings.value?.mirakurunBaseUrl ?? '',
        intervalHours:
            settings.value?.mirakurunEpgRefreshIntervalHours ??
            AppSettingsState.defaultMirakurunEpgRefreshIntervalHours,
      ),
    ),
  );
  if (endpoint.type != BackendType.mirakurun || endpoint.baseUrl.isEmpty) {
    return null;
  }
  const sourceBackend = 'mirakurun';
  final dao = ref.watch(epgDatabaseProvider).epgDao;
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final meta = await dao.getSyncMeta(
    sourceBackend: sourceBackend,
    baseUrl: endpoint.baseUrl,
  );
  switch (decideEpgSync(
    meta: meta,
    baseUrl: endpoint.baseUrl,
    intervalHours: endpoint.intervalHours,
    nowMs: nowMs,
  )) {
    case EpgSyncDecision.useCache:
      _reschedule(
        ref,
        atMs: epgCacheExpiresAtMs(
          fetchedAtMs: meta!.fetchedAtMs,
          intervalHours: endpoint.intervalHours,
        ),
      );
      return EpgSyncState.fromMeta(meta);
    case EpgSyncDecision.clearThenFetch:
      await dao.clearBackend(sourceBackend);
    case EpgSyncDecision.fetch:
      break;
  }
  try {
    final dio = ref.watch(backendDioProvider);
    final result = await const MirakurunEpgFetcher().fetch(dio);
    final fetchedAtMs = DateTime.now().millisecondsSinceEpoch;
    await dao.replaceEpg(
      sourceBackend: sourceBackend,
      baseUrl: endpoint.baseUrl,
      channels: result.channels,
      programs: result.programs,
      fetchedAtMs: fetchedAtMs,
    );
    final next = await dao.getSyncMeta(
      sourceBackend: sourceBackend,
      baseUrl: endpoint.baseUrl,
    );
    _reschedule(
      ref,
      atMs: epgCacheExpiresAtMs(
        fetchedAtMs: fetchedAtMs,
        intervalHours: endpoint.intervalHours,
      ),
    );
    return next == null ? null : EpgSyncState.fromMeta(next);
  } catch (_) {
    final stale = await dao.getSyncMeta(
      sourceBackend: sourceBackend,
      baseUrl: endpoint.baseUrl,
    );
    if (stale != null) {
      // 古い番組表を出し続け、5分後に再試行する。
      _reschedule(
        ref,
        atMs: DateTime.now().millisecondsSinceEpoch + _retryDelayMs,
      );
      return EpgSyncState.fromMeta(stale);
    }
    rethrow;
  }
}

/// 取得失敗時の再試行間隔。
const _retryDelayMs = 5 * 60 * 1000;

/// 指定時刻に自分を invalidate するタイマーを張る。
void _reschedule(Ref ref, {required int atMs}) {
  final delayMs = atMs - DateTime.now().millisecondsSinceEpoch;
  final timer = Timer(
    Duration(milliseconds: delayMs < 0 ? 0 : delayMs),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
}
