import '../entities/channel.dart';
import '../entities/channel_item.dart';
import '../entities/live_stream.dart';

/// サーバー未設定時に送出する例外。UI側で設定誘導表示に使う。
class BackendUnconfiguredException implements Exception {
  const BackendUnconfiguredException();
}

/// バックエンド非依存のテレビ操作インターフェース。
///
/// 新しいバックエンド (EDCB等) を追加する場合はこのクラスを実装し、
/// `tvRepositoryProvider` の factory に1行追加するだけでよい。
abstract class TvRepository {
  /// 放送中チャンネル一覧を返す。次番組も可能な範囲で含める。
  Future<List<ChannelItem>> getNowOnAirChannels();

  /// 接続テスト。成功時は正常終了、失敗時は [Exception] を送出する。
  Future<void> testConnection();

  /// ライブ視聴用のストリーム情報を返す。
  ///
  /// [quality] はKonomiTVの画質指定 (例: `original`)。Mirakurunでは無視され、
  /// `decode=1` 固定のストリームを返す。未設定時は [BackendUnconfiguredException]。
  Future<LiveStream> getLiveStream(Channel channel, {String quality = 'original'});
}
