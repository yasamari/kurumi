import 'package:drift/drift.dart';

/// EPGキャッシュのチャンネル編成テーブル。
///
/// 1行＝(取得元バックエンド, network_id, service_id)。複数バックエンドの
/// 番組表を同時保持するため、同じ放送でも取得元ごとに別行になる。
/// ロゴ・視聴URLは baseUrl を含むため保存せず、`remoteId` から読み出し時に
/// 組み立てる。
class EpgChannels extends Table {
  /// 取得元バックエンド (`BackendType.name`)。
  TextColumn get sourceBackend => text()();

  /// MPEG-TS の network_id。
  IntColumn get networkId => integer()();

  /// MPEG-TS の service_id。
  IntColumn get serviceId => integer()();

  /// バックエンド固有の再生用ID。Mirakurun は `service.id` の文字列表現
  /// (現行 `Channel.id` と同一)。
  TextColumn get remoteId => text()();

  /// 表示名 (`formatProgramText` 済み)。
  TextColumn get name => text()();

  /// チャンネル種別 (`GR`/`BS`/`CS`/`SKY` 等)。
  TextColumn get channelType => text()();

  /// ヘッダー表示用のチャンネル番号 (例: `011`)。なければ空文字。
  TextColumn get channelNumber => text().withDefault(const Constant(''))();

  /// チューナーの物理チャンネル文字。サブチャンネル重複排除キー用。
  /// Mirakurun `service.channel.channel`、なければ空文字。
  TextColumn get tunerChannel => text().withDefault(const Constant(''))();

  /// ロゴデータの有無 (`hasLogoData == true` か)。
  BoolColumn get hasLogo => boolean().withDefault(const Constant(false))();

  /// 取得APIの応答順 (0始まり)。出力順の維持用でソートしない。
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {sourceBackend, networkId, serviceId};
}

/// EPGキャッシュの番組テーブル。
///
/// 1行＝(取得元バックエンド, network_id, service_id, event_id)。
class EpgPrograms extends Table {
  /// 取得元バックエンド (`BackendType.name`)。
  TextColumn get sourceBackend => text()();

  /// MPEG-TS の network_id。
  IntColumn get networkId => integer()();

  /// MPEG-TS の service_id。
  IntColumn get serviceId => integer()();

  /// MPEG-TS の event_id。
  IntColumn get eventId => integer()();

  /// 開始時刻 (ms epoch)。
  IntColumn get startAtMs => integer()();

  /// 終了時刻 (ms epoch。書込時に `startAt + duration` で計算)。
  IntColumn get endAtMs => integer()();

  /// 番組名 (`formatProgramText` 済み)。
  TextColumn get title => text()();

  /// 番組概要 (`formatProgramText` 済み)。なければ空文字。
  TextColumn get description => text().withDefault(const Constant(''))();

  /// 表示用ジャンルラベル配列のJSON。既定 `'[]'`。
  TextColumn get genresJson =>
      text().withDefault(const Constant('[]'))();

  /// 番組詳細 (キー→説明文) のJSON。既定 `'{}'`。
  TextColumn get detailJson =>
      text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey =>
      {sourceBackend, networkId, serviceId, eventId};
}

/// EPG同期状態テーブル。
///
/// (バックエンド, baseUrl) ごとの最終取得時刻と件数。鮮度判定と
/// 接続先変更の検知に使う。
class EpgSyncMeta extends Table {
  /// 同期対象バックエンド (`BackendType.name`)。
  TextColumn get sourceBackend => text()();

  /// 正規化済み baseUrl (サーバー識別・変更検知用)。
  TextColumn get baseUrl => text()();

  /// 取得完了時刻 (ms epoch)。
  IntColumn get fetchedAtMs => integer()();

  /// 書込チャンネル数。
  IntColumn get channelCount => integer()();

  /// 書込番組数。
  IntColumn get programCount => integer()();

  @override
  Set<Column> get primaryKey => {sourceBackend, baseUrl};
}
