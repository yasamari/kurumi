import 'package:drift/drift.dart';

import 'epg_database.dart';
import 'epg_tables.dart';

part 'epg_dao.g.dart';

/// テレビ欄1行分の読出結果。番組側は nullable。
class EpgNowOnAirProgram {
  const EpgNowOnAirProgram({
    required this.eventId,
    required this.startAtMs,
    required this.endAtMs,
    required this.title,
    required this.description,
    required this.genresJson,
    required this.detailJson,
  });

  final int eventId;
  final int startAtMs;
  final int endAtMs;
  final String title;
  final String description;
  final String genresJson;
  final String detailJson;
}

/// テレビ欄の読出1行 (チャンネル＋現在・次番組)。
class EpgNowOnAirRow {
  const EpgNowOnAirRow({
    required this.networkId,
    required this.serviceId,
    required this.remoteId,
    required this.name,
    required this.channelType,
    required this.channelNumber,
    required this.hasLogo,
    required this.present,
    required this.next,
  });

  final int networkId;
  final int serviceId;
  final String remoteId;
  final String name;
  final String channelType;
  final String channelNumber;
  final bool hasLogo;
  final EpgNowOnAirProgram? present;
  final EpgNowOnAirProgram? next;
}

/// EPGキャッシュの読み書き。
@DriftAccessor(tables: [EpgChannels, EpgPrograms, EpgSyncMeta])
class EpgDao extends DatabaseAccessor<EpgDatabase> with _$EpgDaoMixin {
  EpgDao(super.db);

  /// 同期結果で当該バックエンド分を全置換する。
  ///
  /// 接続先URL変更時は呼び出し側で先に [clearBackend] すること
  /// (旧URLの行・meta を残さないため)。
  Future<void> replaceEpg({
    required String sourceBackend,
    required String baseUrl,
    required List<EpgChannelsCompanion> channels,
    required List<EpgProgramsCompanion> programs,
    required int fetchedAtMs,
  }) async {
    await transaction(() async {
      await (delete(epgChannels)
            ..where((c) => c.sourceBackend.equals(sourceBackend)))
          .go();
      await (delete(epgPrograms)
            ..where((p) => p.sourceBackend.equals(sourceBackend)))
          .go();
      await batch((b) {
        b.insertAll(epgChannels, channels);
        b.insertAll(epgPrograms, programs);
      });
      await into(epgSyncMeta).insertOnConflictUpdate(
        EpgSyncMetaCompanion(
          sourceBackend: Value(sourceBackend),
          baseUrl: Value(baseUrl),
          fetchedAtMs: Value(fetchedAtMs),
          channelCount: Value(channels.length),
          programCount: Value(programs.length),
        ),
      );
    });
  }

  /// 指定バックエンドの行・同期状態をすべて消す。
  Future<void> clearBackend(String sourceBackend) async {
    await transaction(() async {
      await (delete(epgChannels)
            ..where((c) => c.sourceBackend.equals(sourceBackend)))
          .go();
      await (delete(epgPrograms)
            ..where((p) => p.sourceBackend.equals(sourceBackend)))
          .go();
      await (delete(epgSyncMeta)
            ..where((m) => m.sourceBackend.equals(sourceBackend)))
          .go();
    });
  }

  /// チャンネル1件を `remoteId` で取得する。なければ null。
  ///
  /// 視聴時のチャンネル解決用。時刻に依存しない one-shot 読出のため、
  /// テレビ欄の毎分再計算の影響を受けない ([mirakurunEpgChannel] 参照)。
  Future<EpgChannel?> getChannel({
    required String sourceBackend,
    required String remoteId,
  }) {
    return (select(epgChannels)..where(
          (c) =>
              c.sourceBackend.equals(sourceBackend) &
              c.remoteId.equals(remoteId),
        ))
        .getSingleOrNull();
  }

  /// 指定バックエンド・URLの同期状態を返す。なければ null。
  Future<EpgSyncMetaData?> getSyncMeta({
    required String sourceBackend,
    required String baseUrl,
  }) {
    return (select(epgSyncMeta)
          ..where(
            (m) =>
                m.sourceBackend.equals(sourceBackend) &
                m.baseUrl.equals(baseUrl),
          ))
        .getSingleOrNull();
  }

  /// テレビ欄を1発SQLで取得する。
  ///
  /// 現行仕様 (`mirakurun_filter.dart`) をSQLに寄せている:
  /// - 放送中でないチャンネルは除外する
  /// - 同じチャンネル種別かつ同じ物理チャンネルで同じ `eventId` の行は
  ///   `sortOrder` が小さい方だけ残す (サブチャンネルの同時放送対策)
  /// - 出力順は取得APIの応答順 (`sortOrder` 順)
  ///
  /// `?` は出現順に [`sourceBackend`, `nowMs`, `nowMs`,
  /// `sourceBackend`, `nowMs`, `nowMs`, `sourceBackend`, `nowMs`,
  /// `sourceBackend`] と束縛する。
  Future<List<EpgNowOnAirRow>> nowOnAir({
    required String sourceBackend,
    required int nowMs,
  }) {
    final query = customSelect(
      _nowOnAirSql,
      variables: [
        Variable.withString(sourceBackend),
        Variable.withInt(nowMs),
        Variable.withInt(nowMs),
        Variable.withString(sourceBackend),
        Variable.withInt(nowMs),
        Variable.withInt(nowMs),
        Variable.withString(sourceBackend),
        Variable.withInt(nowMs),
        Variable.withString(sourceBackend),
      ],
      readsFrom: {epgChannels, epgPrograms},
    );
    return query.map(_readRow).get();
  }
}

/// [EpgDao.nowOnAir] のSQL。`?` の束縛順はメソッド側のコメント参照。
const _nowOnAirSql = '''
WITH ranked AS (
  SELECT
    c.network_id AS c_network_id,
    c.service_id AS c_service_id,
    c.remote_id AS c_remote_id,
    c.name AS c_name,
    c.channel_type AS c_channel_type,
    c.channel_number AS c_channel_number,
    c.tuner_channel AS c_tuner_channel,
    c.has_logo AS c_has_logo,
    c.sort_order AS c_sort_order,
    (SELECT p.rowid FROM epg_programs AS p
      WHERE p.source_backend = ?
        AND p.network_id = c.network_id
        AND p.service_id = c.service_id
        AND p.start_at_ms <= ? AND ? < p.end_at_ms
      ORDER BY p.start_at_ms LIMIT 1) AS present_row,
    (SELECT p.event_id FROM epg_programs AS p
      WHERE p.source_backend = ?
        AND p.network_id = c.network_id
        AND p.service_id = c.service_id
        AND p.start_at_ms <= ? AND ? < p.end_at_ms
      ORDER BY p.start_at_ms LIMIT 1) AS present_event,
    (SELECT p.rowid FROM epg_programs AS p
      WHERE p.source_backend = ?
        AND p.network_id = c.network_id
        AND p.service_id = c.service_id
        AND p.start_at_ms > ?
      ORDER BY p.start_at_ms LIMIT 1) AS next_row
  FROM epg_channels AS c
  WHERE c.source_backend = ?
)
SELECT
  r.*,
  pp.event_id AS p_event_id, pp.start_at_ms AS p_start_at,
  pp.end_at_ms AS p_end_at, pp.title AS p_title,
  pp.description AS p_description,
  pp.genres_json AS p_genres, pp.detail_json AS p_detail,
  np.event_id AS n_event_id, np.start_at_ms AS n_start_at,
  np.end_at_ms AS n_end_at, np.title AS n_title,
  np.description AS n_description,
  np.genres_json AS n_genres, np.detail_json AS n_detail
FROM ranked AS r
LEFT JOIN epg_programs AS pp ON pp.rowid = r.present_row
LEFT JOIN epg_programs AS np ON np.rowid = r.next_row
WHERE r.present_row IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM ranked AS r2
    WHERE r2.present_row IS NOT NULL
      AND r2.c_channel_type = r.c_channel_type
      AND r2.c_tuner_channel = r.c_tuner_channel
      AND r2.present_event = r.present_event
      AND r2.c_sort_order < r.c_sort_order
  )
ORDER BY r.c_sort_order
''';

EpgNowOnAirProgram? _readProgram(
  QueryRow row, {
  required String prefix,
  required String eventIdKey,
}) {
  final eventId = row.readNullable<int>(eventIdKey);
  if (eventId == null) return null;
  return EpgNowOnAirProgram(
    eventId: eventId,
    startAtMs: row.read<int>('${prefix}start_at'),
    endAtMs: row.read<int>('${prefix}end_at'),
    title: row.read<String>('${prefix}title'),
    description: row.read<String>('${prefix}description'),
    genresJson: row.read<String>('${prefix}genres'),
    detailJson: row.read<String>('${prefix}detail'),
  );
}

EpgNowOnAirRow _readRow(QueryRow row) {
  return EpgNowOnAirRow(
    networkId: row.read<int>('c_network_id'),
    serviceId: row.read<int>('c_service_id'),
    remoteId: row.read<String>('c_remote_id'),
    name: row.read<String>('c_name'),
    channelType: row.read<String>('c_channel_type'),
    channelNumber: row.read<String>('c_channel_number'),
    hasLogo: row.read<bool>('c_has_logo'),
    present: _readProgram(row, prefix: 'p_', eventIdKey: 'p_event_id'),
    next: _readProgram(row, prefix: 'n_', eventIdKey: 'n_event_id'),
  );
}
