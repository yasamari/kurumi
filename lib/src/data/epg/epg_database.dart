import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'epg_dao.dart';
import 'epg_tables.dart';

part 'epg_database.g.dart';

/// EPGキャッシュの Drift データベース。
///
/// ファイル配置は `drift_flutter` に委ねる。将来の列追加は `migration` で
/// `ADD COLUMN` し、蓄積済みEPGを消さないこと。
@DriftDatabase(tables: [EpgChannels, EpgPrograms, EpgSyncMeta], daos: [EpgDao])
class EpgDatabase extends _$EpgDatabase {
  EpgDatabase() : super(_open());

  /// テスト用。インメモリ実行器を注入する。
  EpgDatabase.forTesting(super.executor);

  static QueryExecutor _open() => driftDatabase(name: 'kurumi_epg');

  @override
  int get schemaVersion => 1;

  /// テーブルに加えてカスタムインデックスも作る。
  static final _indexes = [
    // テレビ欄の present/next 取得 (相関サブクエリの等値＋範囲シーク用)。
    Index(
      'epg_programs_service_time',
      'CREATE INDEX epg_programs_service_time ON epg_programs '
      '(source_backend, network_id, service_id, start_at_ms)',
    ),
    // 期間重なり取得用 (将来の番組表画面用)。
    Index(
      'epg_programs_span',
      'CREATE INDEX epg_programs_span ON epg_programs '
      '(source_backend, start_at_ms, end_at_ms)',
    ),
    // 将来の番組検索用下地 (FTS5 は作らない)。
    Index(
      'epg_programs_title',
      'CREATE INDEX epg_programs_title ON epg_programs '
      '(source_backend, title)',
    ),
  ];

  // 生成コードの `allTables` が `allSchemaEntities` を参照するため、
  // ここで `allTables` を使うと再帰する。テーブルは明示する。
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    epgChannels,
    epgPrograms,
    epgSyncMeta,
    ..._indexes,
  ];
}
