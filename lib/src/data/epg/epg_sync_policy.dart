import 'epg_database.dart';

/// 同期状態のスナップショット。provider の公開型用
/// (Drift生成クラスを features 層のシグネチャに出さないため)。
class EpgSyncState {
  const EpgSyncState({
    required this.fetchedAtMs,
    required this.channelCount,
    required this.programCount,
  });

  factory EpgSyncState.fromMeta(EpgSyncMetaData meta) {
    return EpgSyncState(
      fetchedAtMs: meta.fetchedAtMs,
      channelCount: meta.channelCount,
      programCount: meta.programCount,
    );
  }

  /// 取得完了時刻 (ms epoch)。
  final int fetchedAtMs;

  /// 書込チャンネル数。
  final int channelCount;

  /// 書込番組数。
  final int programCount;
}

/// 同期要否の判定結果。
enum EpgSyncDecision {
  /// 鮮度内のため取得しない。
  useCache,

  /// 期限切れ・未取得のため取得する。
  fetch,

  /// 接続先が変わったため旧行を消してから取得する。
  clearThenFetch,
}

/// キャッシュの有効期限 (ms epoch) を返す純粋関数。
int epgCacheExpiresAtMs({
  required int fetchedAtMs,
  required int intervalHours,
}) {
  return fetchedAtMs + intervalHours * 3600 * 1000;
}

/// キャッシュが鮮度内かを返す純粋関数。
bool isEpgCacheFresh({
  required int fetchedAtMs,
  required int intervalHours,
  required int nowMs,
}) {
  return nowMs <
      epgCacheExpiresAtMs(
        fetchedAtMs: fetchedAtMs,
        intervalHours: intervalHours,
      );
}

/// 同期要否を判定する純粋関数。
EpgSyncDecision decideEpgSync({
  required EpgSyncMetaData? meta,
  required String baseUrl,
  required int intervalHours,
  required int nowMs,
}) {
  if (meta == null) return EpgSyncDecision.fetch;
  if (meta.baseUrl != baseUrl) return EpgSyncDecision.clearThenFetch;
  if (isEpgCacheFresh(
    fetchedAtMs: meta.fetchedAtMs,
    intervalHours: intervalHours,
    nowMs: nowMs,
  )) {
    return EpgSyncDecision.useCache;
  }
  return EpgSyncDecision.fetch;
}
